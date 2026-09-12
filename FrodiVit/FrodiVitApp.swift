import SwiftData
import SwiftUI

@main
struct FrodiVitApp: App {
    private let container: ModelContainer

    init() {
        // If the disk fails, fall back to memory so the app still answers. The
        // conversation then does not survive a restart, and the screen says so,
        // instead of the app crashing at launch.
        var resolved: ModelContainer
        do {
            resolved = try ModelContainer(for: Chat.self, ChatMessage.self, Document.self, Passage.self)
            Storage.excludeFromBackup(store: resolved)
        } catch {
            Storage.markFailed()
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            // If even this fails, there is nothing left to save.
            resolved = try! ModelContainer(for: Chat.self, ChatMessage.self, Document.self, Passage.self, configurations: memoryOnly)
        }
        container = resolved
    }

    var body: some Scene {
        WindowGroup {
            ChatView()
                // The design system defines light mode only.
                .preferredColorScheme(.light)
                .tint(Color.Frodi.accentKnowledge)
        }
        .modelContainer(container)
    }
}
