import SwiftData
import SwiftUI

/// The knowledge assistant. Write, paste or upload, get an answer.
///
/// The screen follows the sketch: answers at the top, the input field at the
/// bottom, upload to the left of it, and the Info button at the top right.
struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Chat.lastOpenedAt, order: .reverse) private var chats: [Chat]

    // If the model is not in the bundle, the stub says exactly that, instead of
    // MLX failing with something unreadable deep inside loading.
    @State private var conversation = Conversation(
        assistant: BorealisAssistant.isBundled ? BorealisAssistant() : MissingModelAssistant()
    )
    @State private var draft = ""

    /// The conversation the screen is in. `nil` until the first one is made.
    @State private var chat: Chat?
    @State private var showingChats = false
    @State private var showingSettings = false
    @State private var showingImporter = false
    @State private var importError: String?
    @FocusState private var writing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if Storage.failed {
                    storageWarning
                        .padding(.horizontal, Space.s4)
                        .padding(.top, Space.s3)
                }

                if messages.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    transcript
                }

                if !documents.isEmpty {
                    DocumentBar(documents: documents, onRemove: remove)
                }

                inputBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Frodi.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                // Messages from before the app had several conversations have no thread.
                // They are collected here, or they sit invisibly in the store.
                ChatStore.adoptOrphans(in: context)
                if chat == nil { chat = ChatStore.all(in: context).first }
            }
            .sheet(isPresented: $showingChats) {
                ChatListView(chat: $chat)
            }
            .sheet(isPresented: $showingSettings) {
                InfoView()
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: DocumentImport.allowedTypes
            ) { result in
                importDocument(result)
            }
            .alert("Kunne ikke laste opp", isPresented: .constant(importError != nil)) {
                Button("Greit") { importError = nil }
            } message: {
                Text(importError ?? "").font(.Frodi.body)
            }
            .alert("Noe gikk galt", isPresented: .constant(conversation.errorMessage != nil)) {
                Button("Greit") { conversation.dismissError() }
            } message: {
                Text(conversation.errorMessage ?? "").font(.Frodi.body)
            }
        }
    }

    // MARK: - The conversation the screen is in
    /// The conversation shown. Falls back to the last opened one if the one we
    /// were in was deleted from the list.
    private var activeChat: Chat? {
        if let chat, !chat.isDeleted { return chat }
        return chats.first
    }

    private var messages: [ChatMessage] {
        activeChat?.messagesInOrder ?? []
    }

    /// The messages the screen draws. The empty answer bubble waiting for the first
    /// token does not belong here; «Tenker …» covers that state.
    private var visibleMessages: [ChatMessage] {
        messages.filter { !$0.isAwaitingFirstToken }
    }

    private var documents: [Document] {
        activeChat?.documentsInOrder ?? []
    }

    /// The conversation you write in, created only once you actually write or
    /// upload something. An empty conversation per launch would fill the list with
    /// rows you never used.
    private func ensureChat() -> Chat {
        if let activeChat { return activeChat }
        let created = ChatStore.create(orReuse: nil, in: context)
        chat = created
        return created
    }

    // MARK: - Documents
    /// The text that goes into the prompt. A document that cannot be unlocked is
    /// skipped rather than stopping the question.
    private func importDocument(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let text = try DocumentImport.text(from: url)
            let document = try Document(name: url.lastPathComponent, text: text)
            document.chat = ensureChat()
            context.insert(document)
            try context.save()
            // Split and embedded right away, so the question does not have to wait for
            // it. If it fails here, it is redone at the first question.
            Task { try? await Grounding.index(document, in: context) }
        } catch let error as DocumentImport.ImportError {
            importError = "\(error.localizedDescription) \(error.guidance)"
        } catch {
            importError = error.localizedDescription
        }
    }

    private func remove(_ document: Document) {
        context.delete(document)
        try? context.save()
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            VStack(spacing: Space.s1) {
                Text("fróði")
                    .font(.Frodi.display)
                    .foregroundStyle(Color.Frodi.textPrimary)

                // The second half of the app name, not a subtitle. Together the header
                // reads «fróði vit», which is the name of the app.
                Text("vit")
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            // The name as spoken, not the wordmark. Lowercase is a graphic form, not
            // how the name is said.
            .accessibilityLabel("Fróði vit")
            .accessibilityAddTraits(.isHeader)

            // Conversations on the left, new conversation and Info on the right. The
            // wordmark stays centred because it sits in its own layer of the stack, not
            // in the row of buttons.
            HStack(spacing: 0) {
                headerButton("list.bullet", label: "Samtaler") {
                    showingChats = true
                }

                Spacer()

                // Off when the conversation you are in is already empty. Then there is
                // nothing to start afresh from, and the button would look broken.
                headerButton(
                    "square.and.pencil",
                    label: "Ny samtale",
                    isEnabled: canStartNewChat
                ) {
                    chat = ChatStore.create(orReuse: activeChat, in: context)
                }

                headerButton("info.circle", label: "Info om appen") {
                    showingSettings = true
                }
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s2)
        .padding(.bottom, Space.s3)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
    }

    /// There is something to leave: the conversation you are in has content.
    private var canStartNewChat: Bool {
        activeChat.map { !$0.isEmpty } ?? false
    }

    private func headerButton(
        _ symbol: String,
        label: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: ChatControl.actionIcon))
                .foregroundStyle(Color.Frodi.textSecondary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: ChatControl.action, height: ChatControl.action)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    /// The store could not be opened, so the app runs on memory.
    ///
    /// Without this message the conversation would vanish on restart with nothing
    /// to say why.
    private var storageWarning: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Samtalen lagres ikke")
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Fróði får ikke åpnet basen på enheten. Du kan spørre som vanlig, men alt forsvinner når du lukker appen. Installer appen på nytt for å rette det.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.Frodi.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - The conversation
    private var emptyState: some View {
        VStack(spacing: Space.s3) {
            Text("Spør om noe")
                .font(.Frodi.title)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Skriv, lim inn eller last opp et dokument, så svarer Fróði. Alt blir liggende på enheten.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.s8)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .padding(Space.s6)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Space.s3) {
                    ForEach(visibleMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if conversation.isAnswering {
                        thinking
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
            }
            .scrollContentBackground(.hidden)
            .hiddenWhileScreenCaptured()
            .onChange(of: visibleMessages.last?.id) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var thinking: some View {
        HStack(spacing: Space.s3) {
            ProgressView()
            Text("Tenker …")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Space.s4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - The input field
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Space.s2) {
            Button {
                showingImporter = true
            } label: {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: ChatControl.actionIcon))
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .frame(width: ChatControl.action, height: ChatControl.action)
            }
            .accessibilityLabel("Last opp dokument")

            TextField("Skriv eller lim inn her", text: $draft, axis: .vertical)
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .lineLimit(1...5)
                .focused($writing)
                // Writing Tools is the one way the system can send what you write off the
                // device from inside the app: if the text is too large for the on-device
                // model, it goes to Private Cloud Compute. The field is a question, not a
                // document, so it loses nothing by going without.
                .writingToolsBehavior(.disabled)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
                .background(
                    RoundedRectangle(cornerRadius: Radius.pill)
                        .fill(Color.Frodi.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.pill)
                                .strokeBorder(Color.Frodi.border, lineWidth: 1)
                        )
                )

            Button {
                if conversation.isAnswering {
                    conversation.stop()
                } else {
                    conversation.send(draft, in: ensureChat(), documents: documents, context: context)
                    draft = ""
                    writing = false
                }
            } label: {
                Image(systemName: conversation.isAnswering ? "stop.fill" : "arrow.up")
                    .font(.system(size: ChatControl.actionIcon, weight: .semibold))
                    .foregroundStyle(Color.Frodi.accentKnowledgeOn)
                    .frame(width: ChatControl.action, height: ChatControl.action)
                    .background(Circle().fill(Color.Frodi.accentKnowledge))
            }
            .accessibilityLabel(conversation.isAnswering ? "Stopp svaret" : "Send")
            .disabled(!conversation.isAnswering && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s3)
        .background(Color.Frodi.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
    }
}
