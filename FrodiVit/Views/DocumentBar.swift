import SwiftData
import SwiftUI

/// Dokumentene svarene bygger på, som en rad med brikker over skrivefeltet.
///
/// Ligger synlig, ikke bak en skjerm. Har du lastet opp noe, forandrer det hva
/// du får svar på, og da skal du se det uten å lete.
struct DocumentBar: View {
    let documents: [Document]
    let onRemove: (Document) -> Void

    /// Hvilke dokumenter som ikke blir med i sin helhet.
    ///
    /// Regnes ut over hele raden, ikke per brikke: budsjettet deles mellom
    /// dokumentene, så om ett av dem avkortes avhenger av hva annet som
    /// ligger der.
    private var truncated: [Bool] {
        let lengths = documents.map(\.characterCount)
        return zip(lengths, BorealisAssistant.allowances(for: lengths)).map { $1 < $0 }
    }

    var body: some View {
        let flags = truncated
        ScrollView(.horizontal) {
            HStack(spacing: Space.s2) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    chip(for: document, isTruncated: flags[index])
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(for document: Document, isTruncated: Bool) -> some View {
        HStack(spacing: Space.s2) {
            VStack(alignment: .leading, spacing: 0) {
                Text(document.name)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .lineLimit(1)

                if isTruncated {
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
        .accessibilityLabel(spokenLabel(for: document, isTruncated: isTruncated))
    }

    private func spokenLabel(for document: Document, isTruncated: Bool) -> String {
        isTruncated
            ? String(localized: "\(document.name), bare starten er med i svaret")
            : document.name
    }
}
