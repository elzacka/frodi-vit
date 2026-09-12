import SwiftUI

/// Hides content while the screen is being recorded or mirrored.
///
/// iOS offers no way to prevent a screenshot. `userDidTakeScreenshot` arrives
/// only after the picture is taken, and the trick with a hidden
/// `isSecureTextEntry` field is undocumented and can stop working without
/// notice. So we do not pretend to stop screenshots.
///
/// Screen recording and mirroring are different: `isCaptured` is a supported
/// API, and it lasts over time. While it is on, a recording running in the
/// background can capture the text without you thinking about it. So we hide
/// it instead.
///
/// The app switcher is the third case. When the app leaves the foreground, iOS
/// photographs the screen for the switcher and keeps the picture in the app's
/// container, where nothing of ours encrypts it. So the conversation is also
/// hidden whenever the scene is not active, which is before that picture is taken.
struct CaptureGuard: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isCaptured = false

    private var isHidden: Bool { isCaptured || scenePhase != .active }

    func body(content: Content) -> some View {
        Group {
            if isHidden {
                VStack(spacing: Space.s3) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(Color.Frodi.textSecondary)

                    Text(isCaptured ? "Samtalen er skjult mens skjermen tas opp." : "Samtalen er skjult.")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s6)
            } else {
                content
            }
        }
        .onAppear { isCaptured = Self.screenIsCaptured }
        .onReceive(NotificationCenter.default.publisher(
            for: UIScreen.capturedDidChangeNotification
        )) { _ in
            isCaptured = Self.screenIsCaptured
        }
    }

    /// The screen the app is actually shown on.
    ///
    /// `UIScreen.main` is deprecated in iOS 26 because an app can be shown on
    /// several screens. So we take the screen from the scene the app is in. If
    /// there is no scene, the app is not visible, and then there is nothing to
    /// hide.
    @MainActor
    private static var screenIsCaptured: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.screen.isCaptured ?? false
    }
}

extension View {
    /// Hides the content while the screen is being recorded or mirrored.
    func hiddenWhileScreenCaptured() -> some View {
        modifier(CaptureGuard())
    }
}
