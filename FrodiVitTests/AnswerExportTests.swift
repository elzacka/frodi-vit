import Foundation
import Testing
@testable import FrodiVit

@Suite("Eksport av svar")
struct AnswerExportTests {
    @Test("Filen får BOM, teksten og et tidsstempel i navnet")
    func fileIsWrittenWithBOM() throws {
        let date = Date(timeIntervalSince1970: 1_789_200_000)
        let urls = try AnswerExport.prepare("Fristen er 1. oktober.", createdAt: date)
        defer { AnswerExport.cleanUp(urls) }

        let file = try #require(urls.first)
        #expect(file.pathExtension == "txt")
        #expect(file.lastPathComponent.hasPrefix("frodi-vit-2026-"))
        let data = try Data(contentsOf: file)
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
        #expect(String(data: data.dropFirst(3), encoding: .utf8) == "Fristen er 1. oktober.")
    }

    /// Klarteksten skal ikke bli liggende i den midlertidige mappen.
    @Test("Opprydding fjerner mappen")
    func cleanUpRemovesFolder() throws {
        let urls = try AnswerExport.prepare("noe", createdAt: Date())
        let folder = try #require(urls.first).deletingLastPathComponent()
        #expect(FileManager.default.fileExists(atPath: folder.path))
        AnswerExport.cleanUp(urls)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }
}
