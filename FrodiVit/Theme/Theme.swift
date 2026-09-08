import SwiftUI

/// Designsystemet i kode. Verdiene her er de eneste som skal brukes —
/// ingen egendefinerte farger, avstander eller radiuser ute i viewene.
///
/// Kilde: dev_only/designsystem/frodi-designsystem-v1.0.html
///
/// Delt med tale til tekst-appen, men ikke identisk: opptaksfargene finnes
/// ikke her, og `accentKnowledge` er tatt i bruk i stedet. Det er den samme
/// merkevaren, ikke den samme appen.

// MARK: - Farger

extension Color {
    enum Frodi {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let border = Color("BorderNeutral")

        /// Aksentfargen til kunnskapsdelen. Reservert i designsystemet fra
        /// starten, og tatt i bruk her for første gang.
        static let accentKnowledge = Color("AccentKnowledge")
        /// Tekst og ikoner oppå `accentKnowledge`. Aldri ren svart eller hvit.
        static let accentKnowledgeOn = Color("AccentKnowledgeOn")
    }
}

// MARK: - Typografi

extension Font {
    enum Frodi {
        /// Skranji Bold. Logo og appnavn. Samme skrift som i app-ikonet.
        static let display = custom("Skranji-Bold", size: 26, relativeTo: .largeTitle)
        /// Inter 600. Skjermtitler.
        ///
        /// Skranji er en pyntefont og holdes til logoen. Titler må kunne leses
        /// raskt, også med stor tekst, og WCAG 2.2 AA gjelder.
        static let title = custom("Inter-SemiBold", size: 20, relativeTo: .title2)
        /// Inter 500, sporet. Små etiketter over en seksjon.
        static let eyebrow = custom("Inter-Medium", size: 11, relativeTo: .caption2)
        static let body = custom("Inter-Regular", size: 15, relativeTo: .body)
        static let bodyMedium = custom("Inter-Medium", size: 15, relativeTo: .body)
        static let caption = custom("Inter-Regular", size: 13, relativeTo: .footnote)
        static let meta = custom("Inter-Regular", size: 11, relativeTo: .caption2)
    }
}

// MARK: - Avstand

/// 8px-grid. Ingen egendefinerte tall utenfor denne skalaen.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
}

// MARK: - Hjørneradius

enum Radius {
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    /// Meldingsbobler og pilleknapper.
    static let pill: CGFloat = 24
}

// MARK: - Knapper i samtalen

/// Designsystem v1.0 beskriver ingen samtale. Målene er avledet fra
/// treffområdekravet: ingenting under 44 pt.
enum ChatControl {
    static let action: CGFloat = 44
    static let actionIcon: CGFloat = 20
}

// MARK: - Sporing

extension Text {
    /// Eyebrow-etiketter er sporet 0.06em i designsystemet.
    func eyebrowTracking() -> some View {
        tracking(11 * 0.06)
    }
}
