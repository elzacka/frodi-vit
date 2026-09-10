import SwiftData
import SwiftUI

/// Kunnskapsassistenten. Skriv, lim inn eller last opp, få svar.
///
/// Skjermen følger skissen: svarene øverst, skrivefeltet nederst, last opp til
/// venstre for det, og innstillinger øverst til høyre.
struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Chat.lastOpenedAt, order: .reverse) private var chats: [Chat]

    // Er modellen ikke i pakken, sier stubben fra om nettopp det, i stedet for
    // at MLX feiler med noe uleselig langt inne i lastingen.
    @State private var conversation = Conversation(
        assistant: BorealisAssistant.isBundled ? BorealisAssistant() : MissingModelAssistant()
    )
    @State private var draft = ""

    /// Samtalen skjermen står i. `nil` til den første er laget.
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
                // Meldinger fra før appen fikk flere samtaler har ingen tråd.
                // De samles opp her, ellers blir de liggende usynlig i basen.
                ChatStore.adoptOrphans(in: context)
                if chat == nil { chat = ChatStore.all(in: context).first }
            }
            .sheet(isPresented: $showingChats) {
                ChatListView(chat: $chat)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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

    // MARK: - Samtalen skjermen står i

    /// Samtalen som vises. Faller tilbake til den sist åpnede om den vi sto i
    /// ble slettet fra listen.
    private var activeChat: Chat? {
        if let chat, !chat.isDeleted { return chat }
        return chats.first
    }

    private var messages: [ChatMessage] {
        activeChat?.messagesInOrder ?? []
    }

    private var documents: [Document] {
        activeChat?.documentsInOrder ?? []
    }

    /// Samtalen du skriver i, laget først når du faktisk skriver eller laster
    /// opp noe. En tom samtale per oppstart ville fylt listen med rader du
    /// aldri brukte.
    private func ensureChat() -> Chat {
        if let activeChat { return activeChat }
        let created = ChatStore.create(orReuse: nil, in: context)
        chat = created
        return created
    }

    // MARK: - Dokumenter

    /// Teksten som blir med i ledeteksten. Et dokument som ikke lar seg låse
    /// opp hoppes over i stedet for å stoppe spørsmålet.
    private var documentTexts: [String] {
        documents.compactMap { try? $0.text() }
    }

    private func importDocument(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let text = try DocumentImport.text(from: url)
            let document = try Document(name: url.lastPathComponent, text: text)
            document.chat = ensureChat()
            context.insert(document)
            try context.save()
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

    // MARK: - Hode

    private var header: some View {
        ZStack {
            VStack(spacing: Space.s1) {
                Text("fróði")
                    .font(.Frodi.display)
                    .foregroundStyle(Color.Frodi.textPrimary)

                // Andre halvdel av appnavnet, ikke en undertittel. Sammen
                // leser hodet «fróði vit», som er navnet på appen.
                Text("vit")
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            // Navnet uttalt, ikke ordmerket. Små bokstaver er en grafisk form,
            // ikke måten navnet sies på.
            .accessibilityLabel("Fróði vit")
            .accessibilityAddTraits(.isHeader)

            // Samtalene til venstre, ny samtale og innstillinger til høyre.
            // Ordmerket blir stående i midten fordi det ligger i sitt eget lag
            // i stacken, ikke i raden med knapper.
            HStack(spacing: 0) {
                headerButton("list.bullet", label: "Samtaler") {
                    showingChats = true
                }

                Spacer()

                headerButton("square.and.pencil", label: "Ny samtale") {
                    chat = ChatStore.create(orReuse: activeChat, in: context)
                }

                headerButton("gearshape", label: "Innstillinger") {
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

    private func headerButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: ChatControl.actionIcon))
                .foregroundStyle(Color.Frodi.textSecondary)
                .frame(width: ChatControl.action, height: ChatControl.action)
        }
        .accessibilityLabel(label)
    }

    /// Basen lot seg ikke åpne, så appen kjører på minnet.
    ///
    /// Uten denne beskjeden ville samtalen forsvunnet ved omstart uten at noe
    /// tydet på hvorfor.
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

    // MARK: - Samtalen

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
                    ForEach(messages) { message in
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
            .onChange(of: messages.last?.id) { _, id in
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

    // MARK: - Skrivefeltet

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
                    conversation.send(draft, in: ensureChat(), documents: documentTexts, context: context)
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
