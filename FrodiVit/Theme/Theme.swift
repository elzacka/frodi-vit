import SwiftUI

/// The design system in code. The values here are the only ones to use: no
/// custom colours, spacings or radii out in the views.
///
/// Source: `~/dev/frodi/dev_only/designsystem/frodi-designsystem.html`.
/// The design system is shared with Fróði røst and lives in that repo.
///
/// Shared, but not identical: the recording colours do not exist here, and
/// `accentKnowledge` is in use instead. It is the same brand, not the same app.

// MARK: - Colours
extension Color {
    enum Frodi {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let border = Color("BorderNeutral")

        /// The accent colour of the knowledge feature. Reserved in the design system
        /// from the start, and taken into use here for the first time.
        static let accentKnowledge = Color("AccentKnowledge")
        /// Text and icons on top of `accentKnowledge`. Never pure black or white.
        static let accentKnowledgeOn = Color("AccentKnowledgeOn")
    }
}

// MARK: - Typography
extension Font {
    enum Frodi {
        /// Skranji Bold. Logo and app name. The same face as in the app icon.
        static let display = custom("Skranji-Bold", size: 26, relativeTo: .largeTitle)
        /// Inter 600. Screen titles.
        ///
        /// Skranji is a display face and is kept to the logo. Titles must be readable
        /// quickly, also with large text, and WCAG 2.2 AA applies.
        static let title = custom("Inter-SemiBold", size: 20, relativeTo: .title2)
        /// Inter 500, tracked. Small labels above a section.
        static let eyebrow = custom("Inter-Medium", size: 11, relativeTo: .caption2)
        static let body = custom("Inter-Regular", size: 15, relativeTo: .body)
        static let bodyMedium = custom("Inter-Medium", size: 15, relativeTo: .body)
        static let caption = custom("Inter-Regular", size: 13, relativeTo: .footnote)
        static let meta = custom("Inter-Regular", size: 11, relativeTo: .caption2)
    }
}

// MARK: - Spacing
/// 8 px grid. No custom numbers outside this scale.
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

// MARK: - Corner radius
enum Radius {
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    /// Message bubbles and pill buttons.
    static let pill: CGFloat = 24
}

// MARK: - Buttons in the conversation
/// Design system v1.0 describes no conversation. The measures are derived from
/// the hit-area requirement: nothing under 44 pt.
enum ChatControl {
    static let action: CGFloat = 44
    static let actionIcon: CGFloat = 20
}

// MARK: - Tracking
extension Text {
    /// Eyebrow labels are tracked 0.06 em in the design system.
    func eyebrowTracking() -> some View {
        tracking(11 * 0.06)
    }
}
