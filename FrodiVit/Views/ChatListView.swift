import SwiftData
import SwiftUI

/// The conversations you have had, with what you need to tidy them.
///
/// The list has two states. Normally a tap opens the conversation and a swipe
/// deletes the one you swipe on. Tap «Velg» and every row gets a circle, and
/// then you can take several at once or all in one go. It is the same split iOS
/// uses in Mail and Notes, and worth following: that is how people already know
/// it works.
struct ChatListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Chat.lastOpenedAt, order: .reverse) private var chats: [Chat]

    /// The conversation the app is in. If it is deleted, the binding moves on to
    /// the next one, or to none.
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

    // MARK: - The list
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
        // In select mode the row is a checkbox, not a shortcut into the conversation.
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

    // MARK: - Buttons
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
            // A cross, as on the Info page: the sheet just closes.
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

    // MARK: - Text
    private func title(of chat: Chat) -> String {
        // `try?` flattens String?? to String?, so a title that cannot be opened and a
        // conversation without a title both end up here.
        if let title = try? chat.title(), !title.isEmpty { return title }
        return String(localized: "Ny samtale")
    }

    /// «1 meldinger» is the mistake nobody reads past. The singular is spelled out.
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

    // MARK: - Actions
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

    /// Deletes, and makes sure the app is not left in a conversation that is gone.
    /// Without this the screen behind the sheet shows an empty thread you cannot
    /// write in.
    private func delete(_ doomed: [Chat]) {
        let losingCurrent = chat.map { current in doomed.contains { $0.id == current.id } } ?? false
        ChatStore.delete(doomed, in: context)

        if losingCurrent {
            chat = ChatStore.all(in: context).first
        }
    }
}
