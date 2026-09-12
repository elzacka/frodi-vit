import SwiftUI
import UniformTypeIdentifiers

/// En melding i samtalen.
///
/// Ditt eget spørsmål står på aksentflaten til høyre, svaret på surface til
/// venstre. Formen alene skiller dem, så fargen er ikke det eneste som bærer
/// forskjellen — det kravet gjelder også her.
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

                // Hvilke dokumenter svaret bygger på. Uten dette kan du ikke
                // se forskjell på et svar fra teksten din og et modellen fant
                // på selv.
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
        // Veien ut av appen. Svaret er bundet til denne enheten, så dette er
        // den eneste måten å ta det med seg på. Hold fingeren på boblen.
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

    // MARK: - Ut av appen

    /// Bare til denne enheten. Uten `localOnly` følger utklippstavlen med
    /// til de andre enhetene dine gjennom iCloud, og det er en vei ut som
    /// appen ellers ikke har.
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

    /// Teksten ligger forseglet. Får vi den ikke opp, er meldingen kryptert på
    /// en annen enhet, og da sier vi det i stedet for å vise en tom boble.
    private var text: String {
        (try? message.text()) ?? String(localized: "Denne meldingen kan ikke låses opp.")
    }

    /// VoiceOver leser ikke plassering eller farge, så hvem som snakker må stå
    /// i teksten.
    private var sources: String? {
        guard !message.sourceNames.isEmpty else { return nil }
        return String(localized: "Fra \(Self.list(message.sourceNames))")
    }

    /// «a», «a og b», «a, b og c». Ikke `ListFormatter`: den følger språket på
    /// enheten, og appen er norsk uansett hva enheten er satt til.
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
