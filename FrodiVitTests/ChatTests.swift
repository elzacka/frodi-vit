import Foundation
import SwiftData
import Testing
@testable import FrodiVit

@Suite("Samtale")
struct ChatTests {
    /// En base i minnet, slik at hver test starter tom og ingenting havner på
    /// disk.
    @MainActor
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Chat.self, ChatMessage.self, Document.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Tittel

    @Test("Tittelen kommer uendret tilbake")
    func titleRoundTrips() throws {
        let chat = Chat()
        try chat.nameIfUnnamed(from: "Hva står det i leiekontrakten?")
        #expect(try chat.title() == "Hva står det i leiekontrakten?")
    }

    /// Tittelen er hentet fra spørsmålet, og et spørsmål røper ofte mer enn
    /// svaret. Den skal ikke ligge lesbar i basen.
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

    /// Tittelen skal peke på hva tråden startet som. Skiftet den for hvert
    /// spørsmål, ville du ikke kjent den igjen i listen.
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

    /// Kutter på ordskille, ikke midt i et ord: «kontrak…» ser ut som en
    /// skrivefeil, «kontrakten…» gjør ikke det.
    @Test("Lange spørsmål kuttes på et ordskille")
    func longQuestionsAreCutOnAWordBoundary() {
        let title = Chat.title(from: "Kan du forklare hva som står i punkt fire i leiekontrakten min")
        #expect(title == "Kan du forklare hva som står i punkt fire i…")
    }

    /// Ett ord uten mellomrom har ingen ordskille å kutte på. Da kuttes det på
    /// tegn framfor å la tittelen sprenge raden.
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

    // MARK: - Innhold

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

    // MARK: - Sletting

    /// Sletter du samtalen, skal ikke meldingene bli liggende igjen i basen.
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

    // MARK: - Ny samtale

    /// «Ny samtale» to ganger på rad skal ikke legge igjen en tom rad.
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

    // MARK: - Meldinger fra en eldre versjon

    /// Basen hadde én tråd og ingen `Chat`. Uten oppsamlingen ville alt du
    /// hadde spurt om blitt liggende usynlig.
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

    /// Kjøres ved hver oppstart. Andre gang skal den ikke finne noe.
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
