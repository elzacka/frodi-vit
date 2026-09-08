import SwiftUI

/// En melding i samtalen.
///
/// Ditt eget spørsmål står på aksentflaten til høyre, svaret på surface til
/// venstre. Formen alene skiller dem, så fargen er ikke det eneste som bærer
/// forskjellen — det kravet gjelder også her.
struct MessageBubble: View {
    let message: ChatMessage

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
    private var spokenLabel: String {
        let who = isFromUser
            ? String(localized: "Du skrev")
            : String(localized: "Fróði svarte")
        return message.wasInterrupted
            ? "\(who): \(text). \(String(localized: "Svaret ble avbrutt"))"
            : "\(who): \(text)"
    }
}
