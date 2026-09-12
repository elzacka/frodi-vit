import CryptoKit
import Foundation
import Testing
@testable import FrodiVit

@Suite("Kryptering")
struct VaultTests {
    @Test("Forseglet innhold kan åpnes igjen")
    func roundTrip() throws {
        let original = Data("Hva står det i dokumentet jeg lastet opp?".utf8)
        let sealed = try Vault.seal(original)
        #expect(try Vault.open(sealed) == original)
    }

    /// The sealed content must not contain the plaintext.
    @Test("Klarteksten finnes ikke i det forseglede")
    func plaintextIsNotPresent() throws {
        let secret = Data("hemmelig setning som ikke skal lekke".utf8)
        let sealed = try Vault.seal(secret)
        #expect(sealed.range(of: secret) == nil)
        #expect(sealed.count > secret.count)
    }

    /// Every message gets its own data key, so two identical messages must not
    /// give identical ciphertext. Otherwise we leak that the content is the same.
    @Test("Lik inndata gir ulikt chiffer")
    func sameInputGivesDifferentCipher() throws {
        let text = Data("samme spørsmål to ganger".utf8)
        #expect(try Vault.seal(text) != Vault.seal(text))
    }

    @Test("Tuklet innhold blir avvist")
    func tamperedContentIsRejected() throws {
        var sealed = try Vault.seal(Data("noe som skal beskyttes".utf8))
        sealed[sealed.count - 1] ^= 0xFF
        #expect(throws: (any Error).self) { try Vault.open(sealed) }
    }

    @Test("Søppel blir avvist i stedet for å krasje")
    func garbageIsRejected() {
        #expect(throws: (any Error).self) { try Vault.open(Data([0x01])) }
        #expect(throws: (any Error).self) { try Vault.open(Data()) }
    }

    // MARK: - Text
    @Test("Tekst kan forsegles og åpnes igjen")
    func textRoundTrip() throws {
        let text = "Dette er et spørsmål jeg stilte."
        #expect(try Vault.openText(Vault.seal(text)) == text)
    }

    /// æ, ø and å must come back unchanged. If they go through the wrong
    /// character set, it is noticed only when someone reads their answer.
    @Test("Norske tegn overlever forseglingen")
    func norwegianCharactersSurvive() throws {
        let text = "Særlig øvelse gjør mester på Sørlandet – æ, ø og å."
        #expect(try Vault.openText(Vault.seal(text)) == text)
    }

    @Test("Teksten finnes ikke i klartekst i det forseglede")
    func sealedTextIsNotReadable() throws {
        let text = "personnummeret mitt står i dette dokumentet"
        let sealed = try Vault.seal(text)
        #expect(sealed.range(of: Data(text.utf8)) == nil)
    }
}
