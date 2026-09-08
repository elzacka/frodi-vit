import Foundation
import Testing
@testable import FrodiVit

/// Appens løfte er at ingenting forlater telefonen. Disse testene vokter det
/// løftet i koden, ikke i dokumentasjonen.
///
/// Løftet er strengere her enn i Fróði røst: den har lyd i
/// bakgrunnen fordi et opptak må overleve at skjermen låses. Denne appen gjør
/// ingenting i bakgrunnen i det hele tatt.
@Suite("Isolasjon")
struct IsolationTests {
    /// Ingen nettverksnøkler i Info.plist betyr ingen unntak fra ATS.
    @Test("Ingen unntak fra transportsikkerhet")
    func noAppTransportSecurityExceptions() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
        #expect(ats == nil, "NSAppTransportSecurity er lagt inn — appen skal ikke snakke med nett i det hele tatt")
    }

    /// Ingen bakgrunnsmodus overhodet. `fetch` eller `processing` ville åpnet
    /// for arbeid som kan nå nettet mens ingen ser på.
    @Test("Ingenting kjører i bakgrunnen")
    func nothingRunsInBackground() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes == nil, "Uventede bakgrunnsmoduser: \(modes ?? [])")
    }

    /// Denne appen har ingen mikrofon, og skal ikke be om en. Dukker nøkkelen
    /// opp, har noen dratt inn opptak fra den andre appen.
    @Test("Appen ber ikke om mikrofon")
    func doesNotRequestMicrophone() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription")
        #expect(value == nil, "NSMicrophoneUsageDescription hører til Fróði røst")
    }

    /// Talegjenkjenning hører heller ikke hjemme her. Nøkkelen tvinger fram
    /// Apples dialog om at taledata sendes til dem.
    @Test("Appen ber ikke om tilgang til talegjenkjenning")
    func doesNotRequestSpeechRecognition() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription")
        #expect(value == nil)
    }

    /// Personvernmanifestet skal si at appen ikke samler inn noe og ikke sporer.
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

    /// Appen er norsk, og bare norsk. Kommer det flere språk inn, er det en
    /// beslutning som skal tas bevisst, ikke noe som siger inn.
    @Test("Bare bokmål er med")
    func onlyBokmaal() {
        let locales = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        #expect(locales == ["nb"])
    }
}
