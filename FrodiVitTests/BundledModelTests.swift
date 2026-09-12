import Foundation
import Testing
@testable import FrodiVit

/// The model goes in as a folder reference. Lose that reference and the app
/// builds fine and fails only when someone asks a question — and the error then
/// looks like a model error, not a build error. These tests catch it instead.
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

    /// The weights, the tokenizer and the template. Without the template the
    /// messages are sent as loose text and the answers get noticeably worse
    /// without anything failing.
    @Test("Filene modellen trenger er med", arguments: [
        "config.json", "model.safetensors", "tokenizer.json",
        "tokenizer_config.json", "chat_template.jinja"
    ])
    func requiredFilesArePresent(name: String) throws {
        let directory = try #require(BorealisAssistant.modelDirectory)
        let file = directory.appendingPathComponent(name)
        #expect(FileManager.default.fileExists(atPath: file.path), "Mangler \(name)")
    }

    /// 4-bit is chosen to keep the working set within the usual memory limit. If
    /// the model is reconverted with more bits it grows past that, and the app is
    /// killed by the system instead of answering.
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

    // MARK: - The retrieval model
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

    /// `fetch-model.sh` flattens the keys the Swift code reads. If they are
    /// missing, the model was converted outside the script, and the backbone gets
    /// the wrong RoPE base without anything failing loudly.
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
