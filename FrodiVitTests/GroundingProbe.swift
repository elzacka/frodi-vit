import Foundation
import MLX
import SwiftData
import Testing
@testable import FrodiVit

/// Kjører hele veien på enhet: et langt dokument deles, innebygges, søkes i,
/// og svarmodellen får utdragene. Måler tid og minne underveis, og påstår
/// bare det ene som må holde: at setningen svaret trenger er blant utdragene.
///
/// Dokumentet er 40 000 tegn — like langt som NSM-veilederen som drepte appen
/// 11. september 2026 — satt sammen av tjue avsnitt om hvert sitt tema, med
/// én setning gjemt midt i som spørsmålet bare kan besvares fra.
///
/// Kjøres med TEST_RUNNER_FRODI_PROBE=1, og bare på enhet.
#if !targetEnvironment(simulator)
@Suite("Gjenfinningsmåling", .enabled(if: ProcessInfo.processInfo.environment["FRODI_PROBE"] != nil))
struct GroundingProbe {
    static let needle = "Risikovurderingen skal leveres til styret innen 17. mars hvert år, og ansvaret ligger hos sikkerhetslederen."
    static let question = "Når skal risikovurderingen leveres, og hvem har ansvaret?"

    static let topics = [
        "Verdivurderingen kartlegger hva virksomheten har som er verdt å beskytte, og hvilke konsekvenser tap av det ville få for drift, omdømme og liv og helse.",
        "Trusselvurderingen beskriver hvem som kan ønske å ramme virksomheten, hvilke evner de har, og hvor sannsynlig det er at de forsøker.",
        "Sårbarhetene er de svakhetene en trussel kan utnytte: åpne dører, gamle systemer, ansatte uten opplæring og leverandører uten avtale.",
        "Tiltakene skal stå i forhold til risikoen. Et dyrt tiltak mot en usannsynlig hendelse er sjelden riktig prioritering.",
        "Ledelsen eier risikoen. Den kan delegere arbeidet, men ikke ansvaret for at det blir gjort og fulgt opp.",
        "Leverandørene skal vurderes som en del av egen virksomhet. En svak leverandør er en svak virksomhet.",
        "Hendelser skal registreres og læres av. En hendelse som ikke fører til endring, kommer igjen.",
        "Opplæringen skal være jevnlig og tilpasset rollen. Den som håndterer gradert informasjon trenger annet enn den som sitter i resepsjonen.",
        "Fysisk sikring omfatter skallsikring, adgangskontroll og soner. Den som slipper inn i bygget skal ikke dermed slippe inn overalt.",
        "Beredskapsplanen beskriver hvem som gjør hva når noe skjer, og skal øves. En plan som aldri er øvd, er en antakelse.",
        "Informasjonssystemene skal holdes oppdatert, og endringer skal styres. Uplanlagte endringer er en vanlig kilde til svakheter.",
        "Tilgangen til informasjon skal følge behovet. Tilganger som ikke lenger trengs, skal fjernes samme dag som behovet faller bort.",
        "Sikkerhetskulturen er summen av hva de ansatte faktisk gjør når ingen ser på. Den bygges over tid og rives ned fort.",
        "Dokumentasjonen skal være tilstrekkelig til at en utenforstående kan forstå vurderingene og etterprøve dem.",
        "Kontrollen av tiltakene skal skje jevnlig. Et tiltak som er innført, men ikke virker, gir falsk trygghet.",
        "Rapporteringen til ledelsen skal være kort og tydelig, med de viktigste risikoene først og forslag til beslutning.",
        "Personellsikkerhet handler om å kjenne dem som får tilgang, fra ansettelse til avslutning av arbeidsforholdet.",
        "Kryptering beskytter informasjon som er på avveie, men erstatter ikke tilgangskontroll: den som har nøkkelen, har informasjonen.",
        "Sikkerhetsmålene skal være målbare, ellers er det umulig å si om de er nådd.",
        "Avvik fra egne krav skal behandles som hendelser, ikke som unntak, og lukkes med en frist og en ansvarlig.",
    ]

    /// Tjue temaer, gjentatt med et nummer i så teksten varierer, til
    /// lengden er nådd. Nålen legges inn omtrent midt i.
    static func haystack(ofLength length: Int) -> String {
        var paragraphs: [String] = []
        var round = 1
        while paragraphs.joined(separator: "\n\n").count < length {
            for (index, topic) in topics.enumerated() {
                paragraphs.append("Punkt \(round).\(index + 1). \(topic)")
            }
            round += 1
        }
        paragraphs.insert(needle, at: paragraphs.count / 2)
        return paragraphs.joined(separator: "\n\n")
    }

    @Test("Nålen i høystakken, hele veien til et svar")
    @MainActor
    func needleThroughToAnswer() async throws {
        let characters = Int(ProcessInfo.processInfo.environment["FRODI_PROBE_CHARS"] ?? "") ?? 40_000
        let container = try ModelContainer(
            for: Chat.self, ChatMessage.self, Document.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let document = try Document(name: "veileder.txt", text: Self.haystack(ofLength: characters))
        context.insert(document)

        let clock = ContinuousClock()
        print("GROUNDING-\(characters) start fotavtrykk=\(ContextProbe.footprintMB()) MB, ledig=\(ContextProbe.headroomMB()) MB")

        var started = clock.now
        try await Grounding.index(document, in: context)
        print("GROUNDING-\(characters) delt i \(document.passages.count) utdrag og innebygget etter \(clock.now - started), fotavtrykk=\(ContextProbe.footprintMB()) MB")

        started = clock.now
        let grounding = try await Grounding.context(for: Self.question, documents: [document], in: context)
        let joined = grounding.texts.joined(separator: "\n")
        print("GROUNDING-\(characters) valgte \(grounding.texts.count) utdrag, \(joined.count) tegn, etter \(clock.now - started), fotavtrykk=\(ContextProbe.footprintMB()) MB")
        #expect(joined.contains(Self.needle), "Nålen ble ikke valgt")
        #expect(grounding.sources == ["veileder.txt"])

        started = clock.now
        var out = ""
        var peak = ContextProbe.footprintMB()
        var floor = ContextProbe.headroomMB()
        for try await piece in BorealisAssistant().answer(to: Self.question, given: grounding.texts) {
            out += piece
            peak = max(peak, ContextProbe.footprintMB())
            floor = min(floor, ContextProbe.headroomMB())
        }
        print("GROUNDING-\(characters) svar etter \(clock.now - started), topp=\(peak) MB, minst ledig=\(floor) MB")
        print("GROUNDING-\(characters) svar: \(out)")
    }

    /// Innebyggeren lastes og slippes ved hvert kall. Legger hvert kall igjen
    /// noe, dør appen etter noen spørsmål, ikke ved det første.
    @Test("Gjentatte innebygginger legger ikke igjen minne")
    func repeatedEmbeddingsDoNotAccumulate() async throws {
        let pieces = TextSplitter.split(Self.haystack(ofLength: 40_000))
        let embedder = BorealisEmbedder()
        var footprints: [Double] = []
        for round in 1 ... 5 {
            _ = try await embedder.embed(pieces)
            print("GROUNDING-runde \(round) rett etter: fotavtrykk=\(ContextProbe.footprintMB()) MB")
            try await Task.sleep(for: .seconds(1))
            footprints.append(ContextProbe.footprintMB())
            print("GROUNDING-runde \(round): fotavtrykk=\(footprints.last!) MB, mlx aktivt=\(MLX.GPU.activeMemory / 1_048_576) MB, buffer=\(MLX.GPU.cacheMemory / 1_048_576) MB, topp=\(MLX.GPU.peakMemory / 1_048_576) MB")
        }
        #expect(footprints.last! - footprints.first! < 100, "Minnet vokser fra kall til kall")
    }
}
#endif
