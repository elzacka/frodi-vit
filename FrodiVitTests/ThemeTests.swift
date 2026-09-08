import Testing
import UIKit
@testable import FrodiVit

@Suite("Designsystem")
struct ThemeTests {
    /// En font som ikke blir registrert faller stille tilbake til systemfonten.
    /// Da ser appen nesten riktig ut, og feilen oppdages aldri.
    @Test("Alle bundlede fonter lar seg laste", arguments: [
        "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Skranji-Bold"
    ])
    func fontsAreRegistered(name: String) {
        #expect(UIFont(name: name, size: 12) != nil, "Fant ikke fonten \(name)")
    }

    @Test("Fargene i designsystemet finnes i asset-katalogen", arguments: [
        "Background", "Surface", "TextPrimary", "TextSecondary",
        "BorderNeutral", "AccentKnowledge", "AccentKnowledgeOn"
    ])
    func colorsExist(name: String) {
        #expect(UIColor(named: name) != nil, "Fant ikke fargen \(name)")
    }

    /// Opptaksfargene hører til den andre appen. Dukker de opp her, har noen
    /// kopiert inn mer av designsystemet enn denne appen skal ha.
    @Test("Opptaksfargene er ikke med", arguments: [
        "AccentRecord", "AccentRecordOn", "RecordingActive"
    ])
    func recordingColorsAreAbsent(name: String) {
        #expect(UIColor(named: name) == nil, "\(name) hører til Fróði røst")
    }

    /// accent-knowledge er #2E9C82 i designsystemet. En farge som er nesten
    /// riktig er vanskeligere å oppdage enn en som mangler.
    @Test("Kunnskapsfargen har verdien fra designsystemet")
    func knowledgeAccentMatchesDesignSystem() throws {
        let color = try #require(UIColor(named: "AccentKnowledge"))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(Int(round(red * 255)) == 0x2E)
        #expect(Int(round(green * 255)) == 0x9C)
        #expect(Int(round(blue * 255)) == 0x82)
    }
}
