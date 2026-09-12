import Foundation

/// Writes an answer to a text file you can share, and cleans up afterwards.
///
/// The answer is encrypted in the store and cannot be read by another device.
/// This is the way out: plaintext is written to a temporary folder, iOS' share
/// sheet gets the file, and the folder is deleted when the sheet closes. Same
/// pattern as `RecordingExport` in Fróði røst.
enum AnswerExport {
    static func prepare(_ text: String, createdAt: Date) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let file = folder.appendingPathComponent("frodi-vit-\(stamp(createdAt)).txt")
        try utf8WithBOM(text).write(to: file, options: [.completeFileProtectionUnlessOpen])
        return [file]
    }

    /// BOM in front, so Windows and older programs read æ, ø and å correctly.
    static func utf8WithBOM(_ text: String) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    static func cleanUp(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "nb_NO")
        return formatter.string(from: date)
    }
}
