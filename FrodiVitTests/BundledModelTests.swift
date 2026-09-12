import Foundation
import Testing
@testable import FrodiVit

/// Modellen legges inn som mappereferanse. Går den referansen tapt, bygger
/// appen fint og feiler først når noen stiller et spørsmål — og feilen ser da
/// ut som en modellfeil, ikke som en byggefeil. Disse testene fanger det i
/// stedet.
@Suite("Bundlet modell")
struct BundledModelTests {
    @Test("Modellmappen ligger i app-pakken")
    func modelDirectoryExists() throws {
        let directory = try #require(
            BorealisAssistant.modelDirectory,
            "borealis-open-1b mangler. Kjør Scripts/fetch-model.sh."
        )
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    /// Vektene, tokenizeren og malen. Mangler malen, sendes meldingene som løs
    /// tekst og svarene blir merkbart dårligere uten at noe feiler.
    @Test("Filene modellen trenger er med", arguments: [
        "config.json", "model.safetensors", "tokenizer.json",
        "tokenizer_config.json", "chat_template.jinja"
    ])
    func requiredFilesArePresent(name: String) throws {
        let directory = try #require(BorealisAssistant.modelDirectory)
        let file = directory.appendingPathComponent(name)
        #expect(FileManager.default.fileExists(atPath: file.path), "Mangler \(name)")
    }

    /// 4-bit er valgt for å holde arbeidssettet innenfor den vanlige
    /// minnegrensen. Blir modellen konvertert på nytt med flere bit, vokser
    /// den forbi det, og appen blir drept av systemet i stedet for å svare.
    @Test("Modellen er kvantisert til 4 bit")
    func modelIsFourBit() throws {
        let directory = try #require(BorealisAssistant.modelDirectory)
        let data = try Data(contentsOf: directory.appendingPathComponent("config.json"))
        let config = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let quantization = try #require(config["quantization"] as? [String: Any])
        #expect(quantization["bits"] as? Int == 4)
    }

    @Test("Appen ser at modellen er med")
    func assistantSeesTheModel() {
        #expect(BorealisAssistant.isBundled)
    }

    // MARK: - Gjenfinningsmodellen

    @Test("Gjenfinningsmodellen ligger i app-pakken")
    func embedderDirectoryExists() throws {
        let directory = try #require(
            BorealisEmbedder.modelDirectory,
            "borealis-embed-212m mangler. Kjør Scripts/fetch-model.sh."
        )
        #expect(FileManager.default.fileExists(atPath: directory.path))
        #expect(BorealisEmbedder.isBundled)
    }

    @Test("Filene gjenfinningsmodellen trenger er med", arguments: [
        "config.json", "model.safetensors", "tokenizer.json", "tokenizer_config.json"
    ])
    func embedderFilesArePresent(name: String) throws {
        let directory = try #require(BorealisEmbedder.modelDirectory)
        let file = directory.appendingPathComponent(name)
        #expect(FileManager.default.fileExists(atPath: file.path), "Mangler \(name)")
    }

    /// `fetch-model.sh` flater ut nøklene Swift-koden leser. Mangler de, er
    /// modellen konvertert utenom skriptet, og ryggraden får feil RoPE-base
    /// uten at noe feiler høylytt.
    @Test("Gjenfinningsmodellen har de flate nøklene, og er 8 bit")
    func embedderConfigIsFlattened() throws {
        let directory = try #require(BorealisEmbedder.modelDirectory)
        let data = try Data(contentsOf: directory.appendingPathComponent("config.json"))
        let config = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(config["model_type"] as? String == "gemma3_text")
        #expect(config["rope_theta"] as? Int == 100_000)
        #expect(config["rope_local_base_freq"] as? Int == 10_000)
        #expect(config["sliding_window_pattern"] as? Int == 4)
        #expect(config["hidden_activation"] as? String == "silu")
        #expect(config["use_bidirectional_attention"] as? Bool == true)
        let quantization = try #require(config["quantization"] as? [String: Any])
        #expect(quantization["bits"] as? Int == 8)
    }
}
