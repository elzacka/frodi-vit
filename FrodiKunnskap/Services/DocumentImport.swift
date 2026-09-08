import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Henter teksten ut av en fil du har valgt.
///
/// Filen leses én gang, teksten forsegles, og originalen røres ikke. Ingenting
/// kopieres inn i appens mappe: `fileImporter` gir tilgang til akkurat den ene
/// filen, og den tilgangen slippes med det samme.
enum DocumentImport {
    /// Filtypene knappen tilbyr.
    ///
    /// PDF og ren tekst. Ikke `.docx`: iOS har ingen innebygd leser for det,
    /// og et halvveis uttrekk som taper tabeller og overskrifter er verre enn
    /// å si nei.
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

        /// Lengre forklaring, med noe du kan gjøre.
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

    /// Grense på selve filen, før teksten hentes ut.
    ///
    /// Ikke det samme som hvor mye som får plass i ledeteksten. Dette er et
    /// vern mot å låse opp appen på en fil ingen hadde tenkt å laste opp.
    static let maximumFileBytes = 20 * 1024 * 1024

    /// Leser filen og gir teksten tilbake. Kaster med en beskjed du kan vise.
    static func text(from url: URL) throws -> String {
        let name = url.lastPathComponent

        // Filen ligger utenfor sandkassen. Uten dette får vi ikke lese den,
        // og tilgangen skal slippes igjen med én gang vi er ferdige.
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
            // UTF-8 først, så Latin-1. Eldre norske tekstfiler er ofte det
            // siste, og da blir «så» til noe annet uten at noe feiler.
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
