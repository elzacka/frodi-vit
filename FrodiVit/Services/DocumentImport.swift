import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Extracts the text from a file you have chosen.
///
/// The file is read once, the text is sealed, and the original is untouched.
/// Nothing is copied into the app's folder: `fileImporter` grants access to that
/// one file, and the access is released right away.
enum DocumentImport {
    /// The file types the button offers.
    ///
    /// PDF and plain text. Not `.docx`: iOS has no built-in reader for it, and a
    /// half-done extraction that loses tables and headings is worse than saying no.
    static let allowedTypes: [UTType] = [.pdf, .plainText, .utf8PlainText]

    enum ImportError: LocalizedError {
        case unreadable(String)
        case empty(String)
        case tooLarge(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                String(localized: "Fróði fikk ikke lest «\(name)».")
            case .empty(let name):
                String(localized: "Det er ingen tekst å hente ut av «\(name)».")
            case .tooLarge(let name):
                String(localized: "«\(name)» er for stor til å leses inn.")
            }
        }

        /// Longer explanation, with something you can do.
        var guidance: String {
            switch self {
            case .unreadable:
                String(localized: "Filen kan være skadet, eller passordbeskyttet. Prøv å åpne den i Filer først.")
            case .empty:
                String(localized: "Er det en skannet PDF, er sidene bilder uten tekst. Da må teksten hentes ut på en annen måte først.")
            case .tooLarge:
                String(localized: "Del den opp, eller last opp bare den delen du vil spørre om.")
            }
        }
    }

    /// A limit on the file itself, before the text is extracted.
    ///
    /// Not the same as how much fits in the prompt. This is a guard against locking
    /// up the app on a file nobody meant to upload.
    static let maximumFileBytes = 20 * 1024 * 1024

    /// Reads the file and returns the text. Throws with a message you can show.
    static func text(from url: URL) throws -> String {
        let name = url.lastPathComponent

        // The file is outside the sandbox. Without this we cannot read it, and the
        // access must be released again as soon as we are done.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maximumFileBytes else { throw ImportError.tooLarge(name) }

        let extracted: String
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url) else { throw ImportError.unreadable(name) }
            extracted = (0 ..< pdf.pageCount)
                .compactMap { pdf.page(at: $0)?.string }
                .joined(separator: "\n\n")
        } else {
            guard let data = try? Data(contentsOf: url) else {
                throw ImportError.unreadable(name)
            }
            // UTF-8 first, then Latin-1. Older Norwegian text files are often the latter,
            // and then «så» becomes something else without anything failing.
            guard let read = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                throw ImportError.unreadable(name)
            }
            extracted = read
        }

        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.empty(name) }
        return trimmed
    }
}
