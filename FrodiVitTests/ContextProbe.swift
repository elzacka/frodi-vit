import Foundation
import MLX
import Testing
@testable import FrodiVit

/// Måler hva en lang ledetekst koster i tid og minne på enhet. Ikke en test —
/// den påstår ingenting. Kjøres med TEST_RUNNER_FRODI_PROBE=1.
///
/// Kan ikke kjøres i simulatoren: MLX klarer ikke å lage en Metal-enhet der, og
/// avbryter i `mlx::core::metal::Device::Device()` før første token.
@Suite("Kontekstmåling", .enabled(if: ProcessInfo.processInfo.environment["FRODI_PROBE"] != nil))
struct ContextProbe {
    /// Fotavtrykket jetsam måler, ikke residente sider.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1_048_576
    }

    /// Hvor mye appen kan bruke før jetsam tar den.
    static func headroomMB() -> Double {
        Double(os_proc_available_memory()) / 1_048_576
    }

    /// Norsk prosa i omtrent samme sjanger som en veileder, gjentatt til
    /// ønsket lengde. Tokenantallet er det som koster, ikke innholdet.
    static func text(ofLength length: Int) -> String {
        let paragraph = """
            Virksomheten skal identifisere verdier, trusler og sårbarheter, og \
            vurdere hvilken risiko dette gir. Vurderingen skal dokumenteres og \
            behandles av ledelsen. Tiltak prioriteres etter hvor mye de senker \
            risikoen, og etterpå måles det om de virket etter hensikten.

            """
        var out = ""
        while out.count < length { out += paragraph }
        return String(out.prefix(length))
    }

    @Test("Lang ledetekst gjennom modellen")
    @MainActor
    func longPrompt() async throws {
        let environment = ProcessInfo.processInfo.environment
        let characters = Int(environment["FRODI_PROBE_CHARS"] ?? "") ?? 41_000
        let cacheLimit = Int(environment["FRODI_PROBE_CACHE_MB"] ?? "")

        if let cacheLimit {
            MLX.GPU.set(cacheLimit: cacheLimit * 1_048_576)
            print("PROBE bufferttak=\(cacheLimit) MB")
        }

        let document = Self.text(ofLength: characters)
        let question = "Analyser innholdet og beskriv prosessen stegvis på en enkel og overordnet måte."

        print("PROBE-\(characters) start fotavtrykk=\(Self.footprintMB()) MB, ledig=\(Self.headroomMB()) MB")

        let assistant = BorealisAssistant()
        let clock = ContinuousClock()
        let started = clock.now
        var first: Duration?
        var out = ""
        var peak = Self.footprintMB()
        var floor = Self.headroomMB()

        for try await piece in assistant.answer(to: question, given: [document]) {
            if first == nil {
                first = clock.now - started
                print("PROBE-\(characters) første token etter \(first!), fotavtrykk=\(Self.footprintMB()) MB, ledig=\(Self.headroomMB()) MB")
            }
            out += piece
            peak = max(peak, Self.footprintMB())
            floor = min(floor, Self.headroomMB())
        }

        print("PROBE-\(characters) ferdig etter \(clock.now - started), topp=\(peak) MB, minst ledig=\(floor) MB, \(out.count) tegn ut")
    }
}
