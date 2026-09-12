import Foundation
import SwiftData

/// Om basen lot seg åpne, og at den holdes utenfor sikkerhetskopien.
///
/// Gikk åpningen galt, kjører appen videre på minnet. Den virker da helt som
/// vanlig fram til du lukker den, og så er samtalen borte. En stille feil er
/// verre enn en synlig, så skjermen sier fra.
@MainActor
enum Storage {
    private(set) static var failed = false

    static func markFailed() {
        failed = true
    }

    /// Holder databasen utenfor iCloud-sikkerhetskopien.
    ///
    /// Meldingene og dokumentene i den er forseglet, så det som ellers ville
    /// fulgt med er metadata: datoer, antall samtaler, antall meldinger. Lite,
    /// men ingenting av det har noe i en sikkerhetskopi å gjøre. Apple kaller
    /// flagget veiledning, ikke garanti, og det kan bli nullstilt av
    /// filoperasjoner, så det settes ved hver oppstart. SQLite skriver til tre
    /// filer, og alle tre må med.
    static func excludeFromBackup(store container: ModelContainer) {
        for configuration in container.configurations {
            let url = configuration.url
            excludeFromBackup(url)
            for suffix in ["-wal", "-shm"] {
                excludeFromBackup(
                    url.deletingLastPathComponent().appending(path: url.lastPathComponent + suffix)
                )
            }
        }
    }

    private static func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
