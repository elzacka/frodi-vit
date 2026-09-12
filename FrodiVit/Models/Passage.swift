import Foundation
import SwiftData

/// A passage of a document, with the vector retrieval compares against.
///
/// The document is split at import, and every piece gets its vector then. A
/// question therefore costs one vector, not one per paragraph in everything you
/// have uploaded.
///
/// The text is sealed like the document it comes from. The vector is not: 768
/// numbers from a model are not a text you can read back, and unlocking each of
/// them for every question would cost more than it protected.
@Model
final class Passage {
    /// The position in the document. The selection is sorted by it, so the model
    /// reads the passages in the order they appeared.
    var index: Int = 0

    var sealedText: Data = Data()

    /// Number of characters in plaintext, so the selection can count against the
    /// budget without unlocking anything.
    var characterCount: Int = 0

    /// `Float32` back to back, in the device's byte order.
    var vector: Data = Data()

    var document: Document?

    init(index: Int, text: String, vector: [Float]) throws {
        self.index = index
        self.sealedText = try Vault.seal(text)
        self.characterCount = text.count
        self.vector = vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }

    var floats: [Float] {
        vector.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
