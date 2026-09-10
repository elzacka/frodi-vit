import SwiftData
import SwiftUI

/// Samtalene du har hatt, med det du trenger for å rydde i dem.
///
/// Listen har to tilstander. Til vanlig åpner et trykk samtalen, og et sveip
/// sletter den ene du sveiper på. Trykker du «Velg», får hver rad en sirkel,
/// og da kan du ta flere om gangen eller alle på én gang. Det er den samme
/// delingen iOS bruker i Mail og Notater, og den er verdt å følge: det er
/// slik folk allerede vet at det virker.
struct ChatListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Chat.lastOpenedAt, order: .reverse) private var chats: [Chat]

    /// Samtalen appen står i. Slettes den, peker bindingen videre til den
    /// neste, eller til ingen.
    @Binding var chat: Chat?

    @State private var selection = Set<PersistentIdentifier>()
    @State private var isSelecting = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if chats.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.Frodi.background.ignoresSafeArea())
            .navigationTitle("Samtaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .confirmationDialog(
                deleteQuestion,
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Slett", role: .destructive) { deleteSelected() }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Meldingene og dokumentene i dem blir borte for godt. Dette kan ikke angres.")
                    .font(.Frodi.caption)
            }
        }
    }

    // MARK: - Listen

    private var list: some View {
        List(selection: $selection) {
            ForEach(chats) { chat in
                row(for: chat)
                    .listRowBackground(Color.Frodi.surface)
                    .swipeActions(edge: .trailing) {
                        Button("Slett", role: .destructive) { delete([chat]) }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
    }

    private func row(for chat: Chat) -> some View {
        Button {
            open(chat)
        } label: {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(title(of: chat))
                    .font(.Frodi.bodyMedium)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .lineLimit(1)

                Text(meta(of: chat))
                    .font(.Frodi.meta)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // I velgemodus er raden en avkrysning, ikke en snarvei inn i samtalen.
        .disabled(isSelecting)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(of: chat)), \(meta(of: chat))")
        .accessibilityHint(isSelecting ? "Merker samtalen" : "Åpner samtalen")
    }

    private var emptyState: some View {
        VStack(spacing: Space.s3) {
            Text("Ingen samtaler ennå")
                .font(.Frodi.title)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Spør Fróði om noe, så havner samtalen her.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.s8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Knapper

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !chats.isEmpty {
                Button(isSelecting ? "Ferdig" : "Velg") {
                    isSelecting.toggle()
                    selection.removeAll()
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            // Kryss, som i innstillingene: arket bare lukkes.
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Lukk")
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isSelecting {
            HStack {
                Button(allSelected ? "Fjern merking" : "Merk alle") {
                    selection = allSelected ? [] : Set(chats.map(\.id))
                }
                .font(.Frodi.bodyMedium)

                Spacer()

                Button(deleteLabel, role: .destructive) {
                    confirmingDelete = true
                }
                .font(.Frodi.bodyMedium)
                .disabled(selection.isEmpty)
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(Color.Frodi.background)
            .overlay(alignment: .top) { hairline }
        } else {
            Button {
                open(ChatStore.create(orReuse: chat, in: context))
            } label: {
                Label("Ny samtale", systemImage: "square.and.pencil")
                    .font(.Frodi.bodyMedium)
                    .foregroundStyle(Color.Frodi.accentKnowledgeOn)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s3)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .fill(Color.Frodi.accentKnowledge)
                    )
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(Color.Frodi.background)
            .overlay(alignment: .top) { hairline }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.Frodi.border)
            .frame(height: 1)
    }

    // MARK: - Tekst

    private func title(of chat: Chat) -> String {
        // `try?` flater ut String?? til String?, så en tittel som ikke lar seg
        // åpne og en samtale uten tittel havner begge her.
        if let title = try? chat.title(), !title.isEmpty { return title }
        return String(localized: "Ny samtale")
    }

    /// «1 meldinger» er den feilen ingen leser forbi. Entall skrives ut.
    private func meta(of chat: Chat) -> String {
        let count = chat.messages.count
        let stamp = chat.lastOpenedAt.chatStamp
        return switch count {
        case 0: String(localized: "Ingen meldinger · \(stamp)")
        case 1: String(localized: "1 melding · \(stamp)")
        default: String(localized: "\(count) meldinger · \(stamp)")
        }
    }

    private var allSelected: Bool {
        !chats.isEmpty && selection.count == chats.count
    }

    private var deleteLabel: String {
        switch selection.count {
        case 0, 1: String(localized: "Slett")
        default: String(localized: "Slett \(selection.count)")
        }
    }

    private var deleteQuestion: String {
        switch selection.count {
        case 1: String(localized: "Slette samtalen?")
        default: String(localized: "Slette \(selection.count) samtaler?")
        }
    }

    // MARK: - Handlinger

    private func open(_ opened: Chat) {
        ChatStore.open(opened, in: context)
        chat = opened
        dismiss()
    }

    private func deleteSelected() {
        delete(chats.filter { selection.contains($0.id) })
        selection.removeAll()
        isSelecting = false
    }

    /// Sletter, og sørger for at appen ikke blir stående i en samtale som er
    /// borte. Uten dette viser skjermen bak arket en tom tråd du ikke kan
    /// skrive i.
    private func delete(_ doomed: [Chat]) {
        let losingCurrent = chat.map { current in doomed.contains { $0.id == current.id } } ?? false
        ChatStore.delete(doomed, in: context)

        if losingCurrent {
            chat = ChatStore.all(in: context).first
        }
    }
}
