import SwiftUI

/// Skjuler innhold mens skjermen tas opp eller speiles.
///
/// iOS gir ingen måte å hindre et skjermbilde på. `userDidTakeScreenshot`
/// kommer først etter at bildet er tatt, og trikset med et skjult
/// `isSecureTextEntry`-felt er udokumentert og kan slutte å virke uten varsel.
/// Vi later derfor ikke som om vi stopper skjermbilder.
///
/// Skjermopptak og speiling er noe annet: `isCaptured` er et støttet API, og
/// den varer over tid. Er den på, kan et opptak som går i bakgrunnen fange
/// teksten uten at du tenker over det. Da skjuler vi den heller.
struct CaptureGuard: ViewModifier {
    @State private var isCaptured = false

    func body(content: Content) -> some View {
        Group {
            if isCaptured {
                VStack(spacing: Space.s3) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(Color.Frodi.textSecondary)

                    Text("Samtalen er skjult mens skjermen tas opp.")
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

    /// Skjermen appen faktisk vises på.
    ///
    /// `UIScreen.main` er utfaset i iOS 26 fordi en app kan vises på flere
    /// skjermer. Vi henter derfor skjermen fra scenen appen står i.
    /// Finner vi ingen scene, er appen ikke synlig, og da er det ingenting
    /// å skjule.
    @MainActor
    private static var screenIsCaptured: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.screen.isCaptured ?? false
    }
}

extension View {
    /// Skjuler innholdet mens skjermen tas opp eller speiles.
    func hiddenWhileScreenCaptured() -> some View {
        modifier(CaptureGuard())
    }
}
