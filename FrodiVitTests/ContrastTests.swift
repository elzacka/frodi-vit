import Testing
import UIKit
@testable import FrodiVit

/// WCAG 2.2 AA is a requirement, not a goal: 4.5:1 for ordinary text, 3:1 for
/// icons and other graphical elements.
///
/// The test exists because the fault sat there for half a year without being
/// seen. `TextSecondary` was at 3.92:1 against surface and `AccentKnowledgeOn`
/// at 4.04:1 against the accent. Both look right on screen. Only arithmetic
/// catches them.
@Suite("Kontrast")
struct ContrastTests {
    /// Relative luminance as WCAG defines it.
    private static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static func ratio(_ foreground: String, on background: String) throws -> Double {
        let front = try #require(UIColor(named: foreground), "Fant ikke fargen \(foreground)")
        let back = try #require(UIColor(named: background), "Fant ikke fargen \(background)")
        let a = luminance(front), b = luminance(back)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Everything that is text in the app, on every surface text can sit on. Your
    /// own message bubbles have the accent as their ground, so the text there is
    /// the accent pair.
    @Test("Tekst når 4,5:1", arguments: [
        ("TextPrimary", "Background"),
        ("TextPrimary", "Surface"),
        ("TextSecondary", "Background"),
        ("TextSecondary", "Surface"),
        ("AccentKnowledgeOn", "AccentKnowledge")
    ])
    func textMeetsAA(pair: (foreground: String, background: String)) throws {
        let measured = try Self.ratio(pair.foreground, on: pair.background)
        #expect(
            measured >= 4.5,
            "\(pair.foreground) på \(pair.background) er \(String(format: "%.2f", measured)):1, WCAG 2.2 AA krever 4,5:1"
        )
    }

    /// The send button is the only filled surface and must stand out from the
    /// ground. The border is the edge around cards, bubbles and chips, and the
    /// dividers in the header and above the input field.
    @Test("Grafiske element når 3:1", arguments: [
        ("AccentKnowledge", "Background"),
        ("BorderNeutral", "Background"),
        ("BorderNeutral", "Surface")
    ])
    func graphicsMeetAA(pair: (foreground: String, background: String)) throws {
        let measured = try Self.ratio(pair.foreground, on: pair.background)
        #expect(
            measured >= 3.0,
            "\(pair.foreground) på \(pair.background) er \(String(format: "%.2f", measured)):1, WCAG 2.2 AA krever 3:1"
        )
    }
}
