import Foundation
import SwiftData

/// Whether the store could be opened, and keeping it out of the backup.
///
/// If opening failed, the app carries on in memory. It then works exactly as
/// usual until you close it, and then the conversation is gone. A silent failure
/// is worse than a visible one, so the screen says so.
@MainActor
enum Storage {
    private(set) static var failed = false

    static func markFailed() {
        failed = true
    }

    /// Keeps the database out of the iCloud backup.
    ///
    /// The messages and documents in it are sealed, so what would otherwise travel
    /// is metadata: dates, number of conversations, number of messages. Little, but
    /// none of it belongs in a backup. Apple calls the flag guidance, not a
    /// guarantee, and it can be reset by file operations, so it is set at every
    /// launch. SQLite writes to three files, and all three must be covered.
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
