import Foundation
import SwiftData
import Testing
@testable import FrodiVit

@Suite("Samtale")
struct ChatTests {
    /// An in-memory store, so every test starts empty and nothing lands on disk.
    @MainActor
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Chat.self, ChatMessage.self, Document.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Title
    @Test("Tittelen kommer uendret tilbake")
    func titleRoundTrips() throws {
        let chat = Chat()
        try chat.nameIfUnnamed(from: "Hva står det i leiekontrakten?")
        #expect(try chat.title() == "Hva står det i leiekontrakten?")
    }

    /// The title is taken from the question, and a question often reveals more
    /// than the answer. It must not sit readable in the store.
    @Test("Tittelen ligger ikke i klartekst")
    func titleIsSealed() throws {
        let secret = "noe jeg ikke vil at andre skal lese"
        let chat = Chat()
        try chat.nameIfUnnamed(from: secret)
        let sealed = try #require(chat.sealedTitle)
        #expect(sealed.range(of: Data(secret.utf8)) == nil)
    }

    @Test("En ny samtale har ingen tittel")
    func freshChatHasNoTitle() throws {
        #expect(try Chat().title() == nil)
    }

    /// The title should point at what the thread started as. If it changed with
    /// every question, you would not recognise it in the list.
    @Test("Bare det første spørsmålet navngir samtalen")
    func laterQuestionsKeepTheFirstTitle() throws {
        let chat = Chat()
        try chat.nameIfUnnamed(from: "Første spørsmål")
        try chat.nameIfUnnamed(from: "Helt annet spørsmål")
        #expect(try chat.title() == "Første spørsmål")
    }

    @Test("Et tomt spørsmål navngir ingenting")
    func blankQuestionDoesNotName() throws {
        let chat = Chat()
        try chat.nameIfUnnamed(from: "   \n  ")
        #expect(chat.sealedTitle == nil)
    }

    @Test("Korte spørsmål står uendret")
    func shortQuestionsAreKept() {
        #expect(Chat.title(from: "Hva betyr «fróði»?") == "Hva betyr «fróði»?")
    }

    /// Cuts at a word boundary, not mid-word: «kontrak…» looks like a typo,
    /// «kontrakten…» does not.
    @Test("Lange spørsmål kuttes på et ordskille")
    func longQuestionsAreCutOnAWordBoundary() {
        let title = Chat.title(from: "Kan du forklare hva som står i punkt fire i leiekontrakten min")
        #expect(title == "Kan du forklare hva som står i punkt fire i…")
    }

    /// One word without spaces has no word boundary to cut on. Then it is cut on
    /// characters rather than letting the title blow the row.
    @Test("Et enkelt langt ord kuttes likevel")
    func oneLongWordIsStillCut() {
        let title = Chat.title(from: String(repeating: "a", count: 80))
        #expect(title.count == 49)
        #expect(title.hasSuffix("…"))
    }

    @Test("Bare første linje blir tittel")
    func onlyTheFirstLineIsUsed() {
        #expect(Chat.title(from: "Hva er dette?\nOg dette?") == "Hva er dette?")
    }

    @Test("Norske tegn overlever forseglingen")
    func norwegianCharactersSurvive() throws {
        let chat = Chat()
        try chat.nameIfUnnamed(from: "Hvorfor så mange å-er i «håndbøkene»?")
        #expect(try chat.title() == "Hvorfor så mange å-er i «håndbøkene»?")
    }

    // MARK: - Content
    @Test("En fersk samtale er tom")
    func freshChatIsEmpty() {
        #expect(Chat().isEmpty)
    }

    @Test("Meldingene kommer i den rekkefølgen de ble skrevet")
    @MainActor
    func messagesAreOrdered() throws {
        let context = try context()
        let chat = Chat()
        context.insert(chat)

        let now = Date()
        for (offset, text) in ["først", "så", "sist"].enumerated() {
            let message = try ChatMessage(
                role: .user,
                text: text,
                createdAt: now.addingTimeInterval(Double(offset))
            )
            message.chat = chat
            context.insert(message)
        }
        try context.save()

        #expect(try chat.messagesInOrder.map { try $0.text() } == ["først", "så", "sist"])
    }

    // MARK: - Deletion
    /// Delete the conversation and the messages must not be left in the store.
    @Test("Sletting tar med meldingene og dokumentene")
    @MainActor
    func deletingTakesTheContent() throws {
        let context = try context()
        let chat = Chat()
        context.insert(chat)

        let message = try ChatMessage(role: .user, text: "hei")
        message.chat = chat
        context.insert(message)

        let document = try Document(name: "avtale.pdf", text: "innhold")
        document.chat = chat
        context.insert(document)
        try context.save()

        ChatStore.delete([chat], in: context)

        #expect(try context.fetch(FetchDescriptor<Chat>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ChatMessage>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Document>()).isEmpty)
    }

    @Test("Sletting av én samtale lar de andre stå")
    @MainActor
    func deletingOneKeepsTheRest() throws {
        let context = try context()
        let doomed = Chat()
        let kept = Chat()
        context.insert(doomed)
        context.insert(kept)

        let message = try ChatMessage(role: .user, text: "blir stående")
        message.chat = kept
        context.insert(message)
        try context.save()

        ChatStore.delete([doomed], in: context)

        #expect(try context.fetch(FetchDescriptor<Chat>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ChatMessage>()).count == 1)
    }

    // MARK: - New conversation
    /// «Ny samtale» twice in a row must not leave an empty row behind.
    @Test("En tom samtale gjenbrukes")
    @MainActor
    func emptyChatIsReused() throws {
        let context = try context()
        let first = ChatStore.create(orReuse: nil, in: context)
        let second = ChatStore.create(orReuse: first, in: context)

        #expect(first.id == second.id)
        #expect(try context.fetch(FetchDescriptor<Chat>()).count == 1)
    }

    @Test("En samtale med innhold gir en ny")
    @MainActor
    func usedChatYieldsANewOne() throws {
        let context = try context()
        let first = ChatStore.create(orReuse: nil, in: context)
        let message = try ChatMessage(role: .user, text: "hei")
        message.chat = first
        context.insert(message)
        try context.save()

        let second = ChatStore.create(orReuse: first, in: context)

        #expect(first.id != second.id)
        #expect(try context.fetch(FetchDescriptor<Chat>()).count == 2)
    }

    // MARK: - Messages from an older version
    /// The store had one thread and no `Chat`. Without the collection, everything
    /// you had asked would sit invisibly.
    @Test("Løse meldinger samles i én samtale")
    @MainActor
    func orphansAreAdopted() throws {
        let context = try context()
        let now = Date()

        let question = try ChatMessage(role: .user, text: "Hva er dette?", createdAt: now)
        let answer = try ChatMessage(role: .assistant, text: "Et svar", createdAt: now.addingTimeInterval(1))
        let document = try Document(name: "gammel.pdf", text: "tekst")
        context.insert(question)
        context.insert(answer)
        context.insert(document)
        try context.save()

        ChatStore.adoptOrphans(in: context)

        let chats = try context.fetch(FetchDescriptor<Chat>())
        #expect(chats.count == 1)
        let chat = try #require(chats.first)
        #expect(chat.messages.count == 2)
        #expect(chat.documents.count == 1)
        #expect(try chat.title() == "Hva er dette?")
    }

    @Test("Er det ingenting løst, lages ingen samtale")
    @MainActor
    func nothingToAdoptCreatesNothing() throws {
        let context = try context()
        ChatStore.adoptOrphans(in: context)
        #expect(try context.fetch(FetchDescriptor<Chat>()).isEmpty)
    }

    /// Runs at every launch. The second time it must find nothing.
    @Test("Oppsamlingen kan kjøres flere ganger")
    @MainActor
    func adoptionIsIdempotent() throws {
        let context = try context()
        let message = try ChatMessage(role: .user, text: "hei")
        context.insert(message)
        try context.save()

        ChatStore.adoptOrphans(in: context)
        ChatStore.adoptOrphans(in: context)

        #expect(try context.fetch(FetchDescriptor<Chat>()).count == 1)
    }
}
