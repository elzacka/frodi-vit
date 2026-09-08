import Foundation
import MLXLMCommon
import MLXLLM

/// Svarer med borealis-open-1b, kjørt i appen med MLX.
///
/// Modellen ligger som mappereferanse i app-pakken og lastes derfra. Det
/// finnes ingen nedlastingsvei: `MLXHuggingFace` er ikke lenket inn, så en
/// manglende fil feiler i stedet for å hente.
@MainActor
final class BorealisAssistant: Assistant {
    /// Navnet på mappen `Scripts/fetch-model.sh` legger modellen i.
    ///
    /// Mappereferansen i `project.yml` peker på `Resources/Model`, så hele den
    /// mappen havner i app-pakken med navnet sitt i behold. Modellen ligger
    /// altså under `Model/`, ikke i bunnen av pakken.
    nonisolated static let modelDirectoryName = "borealis-open-1b"
    nonisolated static let modelParentName = "Model"

    /// Lastes ved første spørsmål, ikke ved oppstart. En halv gigabyte vekter
    /// skal ikke ligge i minnet mens du bare ser på en tom samtale.
    private var session: ChatSession?

    /// Finnes modellen i pakken i det hele tatt?
    ///
    /// Uten dette faller appen tilbake på en uforståelig feil fra MLX når noen
    /// har hoppet over `fetch-model.sh`. Ren filsjekk, uten tilstand, så den
    /// kan leses fra hvor som helst — blant annet fra testene, som ikke kjører
    /// på hovedaktøren.
    nonisolated static var isBundled: Bool {
        modelDirectory != nil
    }

    nonisolated static var modelDirectory: URL? {
        guard let url = Bundle.main.url(
            forResource: modelDirectoryName,
            withExtension: nil,
            subdirectory: modelParentName
        ) else { return nil }
        // Mappen kan finnes uten å være komplett, om et skript ble avbrutt.
        // Da er det ærligere å si at modellen mangler.
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("config.json").path
        ) ? url : nil
    }

    // Ingen systemledetekst, med vilje.
    //
    // Gemma-malen har ingen system-rolle. Sender du en, limer malen den inn
    // først i den første *bruker*-meldingen. Modellen leste da «Du er Fróði,
    // en hjelpsom assistent …» som noe brukeren hadde skrevet, og svarte på
    // påstanden: «Du er en person som svarer på en robot, og du er Fróði.»
    // Målt på enhet 8. september 2026.
    //
    // Nasjonalbiblioteket har dessuten bakt oppførselen inn i vektene med
    // «prompt baking», nettopp for at ledeteksten ikke skal trenge å stå i
    // konteksten. Deres eget eksempel sender bare en brukermelding.
    //
    // Legg ikke inn en systemledetekst igjen uten å lese malen først.

    /// Strammere enn standard, som er `topP 1.0` — altså ingen filtrering av
    /// halen i det hele tatt. En 1B-modell henter mye tull derfra.
    private static var parameters: GenerateParameters {
        var p = GenerateParameters()
        p.temperature = 0.6
        p.topP = 0.9
        // Uten straff gjentar små modeller gjerne samme setning til taket.
        p.repetitionPenalty = 1.1
        // Et tak, slik at et svar som sporer av tar slutt av seg selv.
        p.maxTokens = 800
        return p
    }

    /// Så mye dokumenttekst som får plass i én ledetekst, til sammen.
    ///
    /// Modellen har 32k tokens kontekst. 48 000 tegn norsk er rundt 15 000
    /// tokens — under halve vinduet, med god plass til spørsmålet og svaret.
    /// NSM-veilederen i risikostyring er 18 sider og 41 191 tegn og går inn
    /// hel. Med den gamle grensen på 8 000 stoppet den på side 5 av 18, og
    /// forside, kolofon og innholdsfortegnelse hadde spist 40 prosent av
    /// budsjettet før veilederen i det hele tatt begynte.
    ///
    /// Grensen gjelder alle dokumentene til sammen, ikke hvert enkelt. Var
    /// den per dokument, ville to opplastinger sprengt vinduet.
    ///
    /// **Ikke målt på enhet:** hvor lenge MLX bruker på å lese 15 000 tokens
    /// før det første ordet kommer, og hvor godt en 1B-modell med glidende
    /// vindu på 512 husker på tvers av så mye tekst. Blir ventetiden for
    /// lang, er svaret å velge ut de relevante delene av dokumentet — ikke å
    /// sette grensen ned igjen.
    nonisolated static let contextCharacterLimit = 48_000

    /// Hvor mange tegn hvert dokument får av budsjettet.
    ///
    /// Korteste dokument først, og hvert av dem får enten det det trenger
    /// eller sin andel av det som er igjen. Et kort notat ved siden av en
    /// lang rapport legger dermed ikke beslag på halve budsjettet uten å
    /// bruke det.
    nonisolated static func allowances(
        for lengths: [Int], within budget: Int = contextCharacterLimit
    ) -> [Int] {
        var allowances = [Int](repeating: 0, count: lengths.count)
        var remaining = budget
        var left = lengths.count
        for index in lengths.indices.sorted(by: { lengths[$0] < lengths[$1] }) {
            let take = min(lengths[index], remaining / left)
            allowances[index] = take
            remaining -= take
            left -= 1
        }
        return allowances
    }

    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let session = try await session()
                    let prompt = Self.prompt(for: question, given: context)
                    for try await piece in session.streamResponse(to: prompt) {
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.translate(error))
                }
            }
        }
    }

    /// Setter sammen spørsmålet med teksten fra dokumentene du har lastet opp.
    ///
    /// Dokumentet står først og spørsmålet sist, fordi modellen er trent på å
    /// svare på det siste som ble sagt. Står spørsmålet øverst, svarer den
    /// gjerne på dokumentet i stedet.
    ///
    /// Dette er ikke gjenfinning. Hele teksten blir med, avkortet mot
    /// ``contextCharacterLimit``, som deles mellom dokumentene. Når
    /// `borealis-embed-212m` lar seg konvertere, er det her utvalget skal
    /// skje i stedet.
    nonisolated static func prompt(for question: String, given context: [String]) -> String {
        let texts = context.filter { !$0.isEmpty }
        let documents = zip(texts, allowances(for: texts.map(\.count)))
            .map { String($0.prefix($1)) }
            .filter { !$0.isEmpty }

        guard !documents.isEmpty else { return question }

        let joined = documents.joined(separator: "\n\n---\n\n")
        return """
            Her er teksten du skal svare ut fra:

            \(joined)

            Svar på dette ut fra teksten over. Står ikke svaret der, si det.

            \(question)
            """
    }

    /// Én økt gjenbrukes på tvers av spørsmål, slik at MLX beholder KV-bufferet
    /// og ikke leser hele samtalen om igjen for hvert svar.
    private func session() async throws -> ChatSession {
        if let session { return session }

        guard let directory = Self.modelDirectory else {
            throw AssistantError.modelMissing
        }

        let model = try await loadModelContainer(
            from: directory, using: LocalTokenizerLoader()
        )
        let session = ChatSession(model, generateParameters: Self.parameters)
        self.session = session
        return session
    }

    /// MLX melder tomt minne som en vanlig feil. Skjermen skal si hva du kan
    /// gjøre med det, ikke gjengi meldingen fra rammeverket.
    private static func translate(_ error: Error) -> Error {
        if error is AssistantError { return error }
        let text = error.localizedDescription.lowercased()
        if text.contains("memory") || text.contains("allocat") {
            return AssistantError.outOfMemory
        }
        return AssistantError.underlying(error.localizedDescription)
    }
}
