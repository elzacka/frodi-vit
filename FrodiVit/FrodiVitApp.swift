import SwiftData
import SwiftUI

@main
struct FrodiVitApp: App {
    private let container: ModelContainer

    init() {
        // Feiler disken, faller vi tilbake til minnet slik at appen fortsatt
        // svarer. Samtalen overlever da ikke omstart, og skjermen sier fra om
        // det, i stedet for at appen kræsjer ved oppstart.
        var resolved: ModelContainer
        do {
            resolved = try ModelContainer(for: Chat.self, ChatMessage.self, Document.self)
            Storage.excludeFromBackup(store: resolved)
        } catch {
            Storage.markFailed()
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            // Klarer vi ikke engang dette, er det ingenting igjen å redde.
            resolved = try! ModelContainer(for: Chat.self, ChatMessage.self, Document.self, configurations: memoryOnly)
        }
        container = resolved
    }

    var body: some Scene {
        WindowGroup {
            ChatView()
                // Designsystemet definerer kun lys modus.
                .preferredColorScheme(.light)
                .tint(Color.Frodi.accentKnowledge)
        }
        .modelContainer(container)
    }
}
