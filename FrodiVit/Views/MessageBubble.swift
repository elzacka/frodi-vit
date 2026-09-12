import SwiftUI
import UniformTypeIdentifiers

/// A message in the conversation.
///
/// Your own question sits on the accent surface to the right, the answer on
/// surface to the left. The shape alone tells them apart, so colour is not the
/// only thing carrying the difference; that requirement applies here too.
struct MessageBubble: View {
    let message: ChatMessage

    @State private var exportURLs: [URL] = []
    @State private var exportError: String?

    var body: some View {
        HStack {
            if isFromUser { Spacer(minLength: Space.s7) }

            VStack(alignment: .leading, spacing: Space.s2) {
                Text(text)
                    .font(.Frodi.body)
                    .foregroundStyle(isFromUser ? Color.Frodi.accentKnowledgeOn : Color.Frodi.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if message.wasInterrupted {
                    Text("Svaret ble avbrutt")
                        .font(.Frodi.meta)
                        .foregroundStyle(isFromUser ? Color.Frodi.accentKnowledgeOn : Color.Frodi.textSecondary)
                }

                // Which documents the answer builds on. Without this you cannot tell an
                // answer from your text apart from one the model made up itself.
                if let sources {
                    Text(sources)
                        .font(.Frodi.meta)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .fill(isFromUser ? Color.Frodi.accentKnowledge : Color.Frodi.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .strokeBorder(Color.Frodi.border, lineWidth: isFromUser ? 0 : 1)
            )

            if !isFromUser { Spacer(minLength: Space.s7) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
        // The way out of the app. The answer is bound to this device, so this is the
        // only way to take it with you. Hold your finger on the bubble.
        .contextMenu {
            if !isFromUser {
                Button("Kopier", systemImage: "doc.on.doc", action: copy)
                Button("Del", systemImage: "square.and.arrow.up", action: share)
            }
        }
        .accessibilityActions {
            if !isFromUser {
                Button("Kopier", action: copy)
                Button("Del", action: share)
            }
        }
        .sheet(isPresented: .constant(!exportURLs.isEmpty)) {
            ShareSheet(urls: exportURLs) {
                AnswerExport.cleanUp(exportURLs)
                exportURLs = []
            }
        }
        .alert("Kunne ikke dele", isPresented: .constant(exportError != nil)) {
            Button("Greit") { exportError = nil }
        } message: {
            Text(exportError ?? "").font(.Frodi.body)
        }
    }

    // MARK: - Out of the app
    /// This device only. Without `localOnly` the pasteboard follows to your other
    /// devices through iCloud, and that is a way out the app otherwise does not have.
    private func copy() {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true])
    }

    private func share() {
        do {
            exportURLs = try AnswerExport.prepare(text, createdAt: message.createdAt)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var isFromUser: Bool {
        message.role == .user
    }

    /// The text is sealed. If we cannot open it, the message was encrypted on
    /// another device, and then we say so instead of showing an empty bubble.
    private var text: String {
        (try? message.text()) ?? String(localized: "Denne meldingen kan ikke låses opp.")
    }

    /// VoiceOver does not read placement or colour, so who is speaking has to be
    /// in the text.
    private var sources: String? {
        guard !message.sourceNames.isEmpty else { return nil }
        return String(localized: "Fra \(Self.list(message.sourceNames))")
    }

    /// «a», «a og b», «a, b og c». Not `ListFormatter`: it follows the device
    /// language, and the app is Norwegian whatever the device is set to.
    nonisolated static func list(_ names: [String]) -> String {
        let quoted = names.map { "«\($0)»" }
        guard quoted.count > 1 else { return quoted.joined() }
        return quoted.dropLast().joined(separator: ", ") + " og " + quoted.last!
    }

    private var spokenLabel: String {
        let who = isFromUser
            ? String(localized: "Du skrev")
            : String(localized: "Fróði svarte")
        var parts = ["\(who): \(text)"]
        if message.wasInterrupted { parts.append(String(localized: "Svaret ble avbrutt")) }
        if let sources { parts.append(sources) }
        return parts.joined(separator: ". ")
    }
}
