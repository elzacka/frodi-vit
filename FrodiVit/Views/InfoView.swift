import SwiftData
import SwiftUI

/// The Info page, behind the i at the top right.
///
/// The sketch put Om fróði, Personvern and Versjonsinfo in a menu of their own
/// on the start screen. This app has no start screen — it opens straight into
/// the conversation — so the three belong here rather than on a screen that
/// would exist only to hold them.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var messages: [ChatMessage]
    @Query private var chats: [Chat]

    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    about
                    privacy
                    conversation
                    languageModel
                    licenses
                    version
                }
                .padding(Space.s4)
            }
            .background(Color.Frodi.background.ignoresSafeArea())
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // A cross, not «Ferdig»: there is nothing to confirm here, the sheet just
                    // closes. The icon also carries no type, so the question of Inter beside the
                    // system title goes away. VoiceOver needs the name the button does not write.
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Lukk")
                }
            }
        }
    }

    // MARK: - Cards
    private var about: some View {
        card("Fróði vit") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Fróði svarer på det du spør om. Alt skjer på enheten.")
            paragraph("Skriv spørsmålet, eller lim inn en tekst. Vil du ha svar som bygger på et dokument, laster du det opp først.")
        }
    }

    private var privacy: some View {
        card("Personvern") {
            paragraph("Alt skjer på enheten. Ingen datatrafikk ut eller inn.")
            paragraph("Alt du skriver og laster opp krypteres med en nøkkel som lages i enheten (Secure Enclave). Ingen annen enhet kan lese det, og det følger ikke med i en sikkerhetskopi.")
            paragraph("Bytter du enhet, følger ikke innholdet med. Sletter du appen, forsvinner alt med én gang.")
            link("Mer om personvern", to: Self.privacyPolicy)
            link("Mer om sikkerhet", to: Self.securityPolicy)
        }
    }

    private var conversation: some View {
        card("Samtaler") {
            paragraph(chatCount)
            if !messages.isEmpty { paragraph(messageCount) }
            paragraph("Alt ligger kryptert på enheten til du sletter det.")
            paragraph("Vil du slette én eller noen få, gjør du det i listen over samtaler.")

            Button("Slett alle samtaler", role: .destructive) {
                confirmingDelete = true
            }
            .font(.Frodi.bodyMedium)
            .disabled(chats.isEmpty)
            .confirmationDialog(
                "Slette alle samtaler?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Slett alle", role: .destructive) { deleteAll() }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Meldingene og dokumentene blir borte for godt. Dette kan ikke angres.")
                    .font(.Frodi.caption)
            }
        }
    }

    /// «1 samtaler» is the mistake nobody reads past. The singular is spelled out.
    private var chatCount: String {
        switch chats.count {
        case 0: String(localized: "Du har ingen samtaler.")
        case 1: String(localized: "Du har én samtale.")
        default: String(localized: "Du har \(chats.count) samtaler.")
        }
    }

    private var messageCount: String {
        switch messages.count {
        case 1: String(localized: "Til sammen én melding.")
        default: String(localized: "Til sammen \(messages.count) meldinger.")
        }
    }

    private var languageModel: some View {
        card("Språkmodell") {
            if BorealisAssistant.isBundled {
                paragraph("borealis-open-1b fra Nasjonalbiblioteket lager svarene. Modellen følger med appen og kjører inne i den.")
                paragraph("Den er trent på norsk, og liten nok til å kjøre på en enhet. Til gjengjeld svarer den kortere enn en modell på nett, og den kan ta feil. Sjekk viktige svar mot kilden.")
                if BorealisEmbedder.isBundled {
                    paragraph("borealis-embed-212m, også fra Nasjonalbiblioteket, finner de delene av et dokument som gjelder spørsmålet. Svaret sier hvilke dokumenter det bygger på.")
                }
            } else {
                paragraph("Språkmodellen er ikke med i dette bygget, så Fróði kan ikke svare. Installer appen på nytt.")
            }
        }
    }

    private var licenses: some View {
        NavigationLink {
            LicensesView()
        } label: {
            card("Lisenser", opensScreen: true) {
                paragraph("Modellene, koden og fontene appen bygger på, med opphav og lisens.")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modeller, kode og fonter")
    }

    private var version: some View {
        card("Versjon") {
            paragraph("Fróði vit \(Self.versionText)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    // The links open in Safari. The app fetches nothing itself; it is the browser
    // that goes online, and only when you tap.
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-vit/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-vit/blob/main/SECURITY.md")!

    /// Version and build number, as they stand in the bundle.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    // MARK: - Building blocks
    /// The settings card from the design system: eyebrow label in capitals over
    /// body text in caption, on surface with a 1 px border.
    @ViewBuilder
    private func card(_ label: String, opensScreen: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Text(label)
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                if opensScreen {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }

            content()
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
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A link out of the app, at the same size as the body text. Underlined and in
    /// text-primary, so it differs from the text around it by more than colour.
    private func link(_ title: String, to url: URL) -> some View {
        Link(title, destination: url)
            .font(.Frodi.caption)
            .underline()
            .tint(Color.Frodi.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Deletes everything. The messages and documents follow the conversations
    /// through `cascade`, so it is the conversations that are deleted here.
    private func deleteAll() {
        // Loose messages from an older version belong to no conversation, and
        // would be left behind after «slett alt».
        for message in messages where message.chat == nil { context.delete(message) }
        ChatStore.delete(chats, in: context)
    }
}

/// The attribution the licences require, in the app and not only in the repo.
///
/// Same content as TREDJEPART.md. Change one, change the other.
struct LicensesView: View {
    private struct Component: Identifiable {
        let name: String
        let origin: String
        let license: String

        var id: String { name }
    }

    private let models = [
        Component(name: "borealis-open-1b", origin: "Nasjonalbiblioteket", license: "Gemma Terms of Use"),
        Component(name: "borealis-embed-212m", origin: "Nasjonalbiblioteket", license: "NB-lisens 1.0")
    ]

    private let code = [
        Component(name: "mlx-swift-lm", origin: "Apple", license: "MIT"),
        Component(name: "mlx-swift", origin: "Apple", license: "MIT"),
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-huggingface", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-jinja", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-numerics", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-collections", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-crypto", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-asn1", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-syntax", origin: "Apple", license: "Apache 2.0"),
        Component(name: "eventsource", origin: "Launch Darkly", license: "Apache 2.0"),
        Component(name: "yyjson", origin: "Yao Yuan", license: "MIT")
    ]

    private let fonts = [
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1"),
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1")
    ]

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    group("Modeller", models)
                    group("Kode", code)
                    group("Fonter", fonts)
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle("Lisenser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
    }

    private func group(_ label: String, _ components: [Component]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(label)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(components) { component in
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name)
                        .font(.Frodi.bodyMedium)
                        .foregroundStyle(Color.Frodi.textPrimary)

                    Text("\(component.origin) · \(component.license)")
                        .font(.Frodi.meta)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
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
    }
}
