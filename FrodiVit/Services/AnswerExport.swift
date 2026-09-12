import Foundation

/// Skriver et svar til en tekstfil du kan dele, og rydder opp etterpå.
///
/// Svaret ligger kryptert i basen og kan ikke leses av en annen enhet. Dette
/// er veien ut: klartekst skrives til en midlertidig mappe, iOS' delingsmeny
/// får filen, og mappen slettes når menyen lukkes. Samme mønster som
/// `RecordingExport` i Fróði røst.
enum AnswerExport {
    static func prepare(_ text: String, createdAt: Date) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let file = folder.appendingPathComponent("frodi-vit-\(stamp(createdAt)).txt")
        try utf8WithBOM(text).write(to: file, options: [.completeFileProtectionUnlessOpen])
        return [file]
    }

    /// BOM foran, så Windows og eldre programmer leser æ, ø og å riktig.
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
