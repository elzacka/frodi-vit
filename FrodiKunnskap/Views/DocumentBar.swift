import SwiftData
import SwiftUI

/// Dokumentene svarene bygger på, som en rad med brikker over skrivefeltet.
///
/// Ligger synlig, ikke bak en skjerm. Har du lastet opp noe, forandrer det hva
/// du får svar på, og da skal du se det uten å lete.
struct DocumentBar: View {
    let documents: [Document]
    let onRemove: (Document) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.s2) {
                ForEach(documents) { document in
                    chip(for: document)
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(for document: Document) -> some View {
        HStack(spacing: Space.s2) {
            VStack(alignment: .leading, spacing: 0) {
                Text(document.name)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .lineLimit(1)

                if document.isTruncatedInPrompt {
                    // Sier fra framfor å late som hele teksten er med.
                    Text("bare starten er med")
                        .font(.Frodi.meta)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }

            Button {
                onRemove(document)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("Fjern \(document.name)")
        }
        .padding(.leading, Space.s3)
        .padding(.trailing, Space.s1)
        .padding(.vertical, Space.s2)
        .background(
            Capsule()
                .fill(Color.Frodi.surface)
                .overlay(Capsule().strokeBorder(Color.Frodi.border, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel(for: document))
    }

    private func spokenLabel(for document: Document) -> String {
        document.isTruncatedInPrompt
            ? String(localized: "\(document.name), bare starten er med i svaret")
            : document.name
    }
}
