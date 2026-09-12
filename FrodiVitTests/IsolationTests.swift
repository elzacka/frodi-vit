import Foundation
import SwiftData
import Testing
@testable import FrodiVit

/// The app's promise is that nothing leaves the device. These tests guard that
/// promise in the code, not in the documentation.
///
/// The promise is stricter here than in Fróði røst: that app has background
/// audio because a recording must survive the screen locking. This app does
/// nothing in the background at all.
@Suite("Isolasjon")
struct IsolationTests {
    /// No network keys in Info.plist means no ATS exceptions.
    @Test("Ingen unntak fra transportsikkerhet")
    func noAppTransportSecurityExceptions() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
        #expect(ats == nil, "NSAppTransportSecurity er lagt inn — appen skal ikke snakke med nett i det hele tatt")
    }

    /// No background mode whatsoever. `fetch` or `processing` would open the door
    /// to work that can reach the network while nobody is watching.
    @Test("Ingenting kjører i bakgrunnen")
    func nothingRunsInBackground() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes == nil, "Uventede bakgrunnsmoduser: \(modes ?? [])")
    }

    /// This app has no microphone, and must not ask for one. If the key shows up,
    /// someone has pulled recording in from the other app.
    @Test("Appen ber ikke om mikrofon")
    func doesNotRequestMicrophone() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription")
        #expect(value == nil, "NSMicrophoneUsageDescription hører til Fróði røst")
    }

    /// Speech recognition does not belong here either. The key forces Apple's
    /// dialog about speech data being sent to them.
    @Test("Appen ber ikke om tilgang til talegjenkjenning")
    func doesNotRequestSpeechRecognition() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription")
        #expect(value == nil)
    }

    /// The privacy manifest must say the app collects nothing and does not track.
    @Test("Personvernmanifestet erklærer ingen innsamling")
    func privacyManifestDeclaresNothing() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
    }

    /// The app is Norwegian, and Norwegian only. If more languages come in, that is
    /// a decision to be taken deliberately, not something that seeps in.
    @Test("Bare bokmål er med")
    func onlyBokmaal() {
        let locales = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        #expect(locales == ["nb"])
    }

    /// The database must not end up in the iCloud backup. The content is sealed,
    /// but dates and counts are not.
    @Test("Databasen er holdt utenfor sikkerhetskopi")
    @MainActor
    func storeIsExcludedFromBackup() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".store")
        let container = try ModelContainer(
            for: Chat.self, ChatMessage.self, Document.self,
            configurations: ModelConfiguration(url: url)
        )
        defer { try? FileManager.default.removeItem(at: url) }

        Storage.excludeFromBackup(store: container)

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
