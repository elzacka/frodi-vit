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
    /// **Grensen er satt av minnet på enheten, ikke av kontekstvinduet.**
    /// Modellen tåler 32k tokens. Enheten gjør det ikke: vektene og
    /// KV-bufferet ligger i minnet samtidig, og jetsam tar appen lenge før
    /// vinduet er fullt.
    ///
    /// Målt på iPhone 17 Pro 11. september 2026, med `ContextProbe`. Taket
    /// enheten gir appen er rundt 3 376 MB:
    ///
    /// | Tegn | Topp | Ledig igjen | Utfall |
    /// |---|---|---|---|
    /// | 8 000 | 2 712 MB | 664 MB | Svarer |
    /// | 10 000 | 2 868 MB | 508 MB | Svarer |
    /// | 12 000 | 3 065 MB | 310 MB | Svarer, med lite igjen |
    /// | 16 000 | – | – | Drept før første token |
    /// | 41 000 | – | – | Drept før første token |
    ///
    /// Rundt 2 090 MB går med før første tegn dokumenttekst, og hver 1 000
    /// tegn koster omtrent 78 MB til. Kurven er rett, og taket ligger like
    /// over 14 000 tegn på denne enheten.
    ///
    /// Grensen sto på 48 000 i to dager. Det tallet kom fra kontekstvinduet
    /// og var aldri målt: NSM-veilederen på 41 191 tegn drepte appen før
    /// første ord, hver gang. 8 000 er verdien den hadde før, og den gir mest
    /// margin til enheter med mindre minne enn denne.
    ///
    /// Prisen er at et langt dokument avkortes. `DocumentBar` sier fra med
    /// «bare starten er med», så en avkortet tekst er synlig framfor stille.
    /// Veien ut er å velge ut de relevante delene med `borealis-embed-212m`,
    /// ikke å sette grensen opp igjen.
    ///
    /// Grensen gjelder alle dokumentene til sammen, ikke hvert enkelt. Var
    /// den per dokument, ville to opplastinger sprengt vinduet.
    nonisolated static let contextCharacterLimit = 8_000

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
