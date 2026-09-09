import Foundation

/// Porten mot språkmodellen. Alt som lager tekst går gjennom denne, slik at
/// modellen kan byttes uten at viewene merker det.
///
/// Samme grep som `Transcriber` i Fróði røst, og av samme grunn:
/// den modellen ble byttet én gang allerede, fra Apples motor til nb-whisper,
/// uten at et eneste view ble rørt.
///
/// Bundet til hovedaktøren fordi kjøretidene for språkmodeller sjelden er
/// `Sendable`. Selve regnearbeidet skjer på GPU-en uansett.
@MainActor
protocol Assistant {
    /// Svarer på spørsmålet, ett tekststykke om gangen.
    ///
    /// Strømming er ikke pynt. Målt avkoding for en liten Gemma-modell på
    /// iPhone 17 er tregere med MLX enn med de fleste alternativene, og et
    /// svar som kommer ord for ord er til å holde ut. Det samme svaret bak en
    /// snurrende sirkel er det ikke.
    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error>
}

enum AssistantError: LocalizedError {
    case modelMissing
    case outOfMemory
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            String(localized: "Språkmodellen mangler i appen.")
        case .outOfMemory:
            String(localized: "Enheten hadde ikke nok minne til å svare.")
        case .underlying(let message):
            message
        }
    }

    /// Lengre forklaring til skjermen. Sier hva du kan gjøre, ikke bare hva
    /// som gikk galt.
    var guidance: String {
        switch self {
        case .modelMissing:
            String(localized: "Fróði fant ikke språkmodellen. Den følger med appen, så dette betyr som regel at installasjonen er ufullstendig. Installer appen på nytt.")
        case .outOfMemory:
            String(localized: "Enheten hadde ikke nok minne. Lukk noen andre apper og prøv igjen.")
        case .underlying:
            String(localized: "Svaret ble ikke ferdig denne gangen. Prøv igjen.")
        }
    }
}

/// Står inne for modellen fram til MLX er koblet på.
///
/// Den svarer ikke, den forklarer hvorfor den ikke svarer. Poenget er at
/// resten av appen — samtalen, forseglingen, skjermen — kan bygges og testes
/// ferdig før modellen på nesten en gigabyte kommer inn i bildet.
struct MissingModelAssistant: Assistant {
    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AssistantError.modelMissing)
        }
    }
}
