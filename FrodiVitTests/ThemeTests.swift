import Testing
import UIKit
@testable import FrodiVit

@Suite("Designsystem")
struct ThemeTests {
    /// A font that is not registered silently falls back to the system font. The
    /// app then looks almost right, and the fault is never noticed.
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

    /// The recording colours belong to the other app. If they show up here,
    /// someone has copied in more of the design system than this app should have.
    @Test("Opptaksfargene er ikke med", arguments: [
        "AccentRecord", "AccentRecordOn", "RecordingActive"
    ])
    func recordingColorsAreAbsent(name: String) {
        #expect(UIColor(named: name) == nil, "\(name) hører til Fróði røst")
    }

    /// accent-knowledge is #2E9C82 in the design system. A colour that is almost
    /// right is harder to spot than one that is missing.
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
