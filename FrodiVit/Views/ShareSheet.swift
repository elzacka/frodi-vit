import SwiftUI
import UIKit

/// iOS' egen delingsmeny. Brukes bare til eksport, og lar deg velge Filer
/// eller AirDrop – begge lokale.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
