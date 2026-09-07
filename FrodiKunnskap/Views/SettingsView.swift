import SwiftData
import SwiftUI

/// Innstillinger, som i skissen ligger bak tannhjulet øverst til høyre.
///
/// Skissen la Om fróði, Personvern og Versjonsinfo i en egen meny på
/// startskjermen. Denne appen har ingen startskjerm — den åpner rett i
/// samtalen — så de tre hører hjemme her i stedet for på en skjerm som bare
/// ville eksistert for å holde dem.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var messages: [ChatMessage]

    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    about
                    privacy
                    conversation
                    version
                }
                .padding(Space.s4)
            }
            .background(Color.Frodi.background.ignoresSafeArea())
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                        .font(.Frodi.bodyMedium)
                }
            }
        }
    }

    private var about: some View {
        card(title: "Om Fróði vit") {
            Text("Fróði svarer på det du spør om, og gjør det på telefonen. Navnet er norrønt og betyr «den kunnskapsrike».")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacy: some View {
        card(title: "Personvern") {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Fróði har ingen nettverkskode. Det du skriver og laster opp blir liggende på denne telefonen, kryptert med en nøkkel som ligger i maskinvaren og aldri forlater den.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Det betyr også at innholdet ikke kan leses av en annen telefon, og ikke følger med i en sikkerhetskopi.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var conversation: some View {
        card(title: "Samtalen") {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text(messages.isEmpty
                     ? String(localized: "Du har ingen meldinger.")
                     : String(localized: "Du har \(messages.count) meldinger."))
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)

                Button("Slett samtalen", role: .destructive) {
                    confirmingDelete = true
                }
                .font(.Frodi.bodyMedium)
                .disabled(messages.isEmpty)
                .confirmationDialog(
                    "Slette hele samtalen?",
                    isPresented: $confirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("Slett", role: .destructive) { deleteAll() }
                    Button("Avbryt", role: .cancel) {}
                } message: {
                    Text("Meldingene blir borte for godt. Dette kan ikke angres.")
                        .font(.Frodi.caption)
                }
            }
        }
    }

    private var version: some View {
        card(title: "Versjon") {
            Text(Self.versionText)
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
        }
    }

    /// Versjon og byggenummer, slik de står i pakken.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    private func card<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .foregroundStyle(Color.Frodi.textSecondary)
                .textCase(.uppercase)

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

    private func deleteAll() {
        for message in messages { context.delete(message) }
        try? context.save()
    }
}
