import CryptoKit
import Foundation
import Security

/// Krypterer det du skriver, limer inn og laster opp, med en nøkkel som aldri
/// forlater denne enheten.
///
/// Hvorfor dette i tillegg til iOS' egen filbeskyttelse: Apple beskriver
/// `isExcludedFromBackup` som veiledning til systemet, ikke en garanti. Slipper
/// en kopi likevel ut, er den uleselig uten nøkkelen — og nøkkelen finnes bare
/// inne i Secure Enclave på denne enheten.
///
/// Oppbygging:
/// - En P-256-nøkkel lages i Secure Enclave og forlater den aldri.
/// - Hvert dokument og hver melding får sin egen tilfeldige AES-256-nøkkel.
/// - Innholdet forsegles med AES-GCM, og AES-nøkkelen pakkes inn av
///   Enclave-nøkkelen.
///
/// Dokumentene du laster opp er mer avslørende enn en lydfil: de er søkbare
/// og lesbare på et blikk. Derfor ligger både dem og samtalen forseglet, ikke
/// bare bak sandkassen.
///
/// Prisen er at innholdet ikke kan leses av en annen enhet. Det er meningen,
/// men det gjør uthenting nødvendig: et svar du vil ta vare på må kunne låses
/// opp og deles mens du har enheten. Den delen er ikke bygd ennå.
enum Vault {
    // Navnet er fra før appen het Fróði vit, og prefikset er `no.` mens
    // bundle-ID-en er `com.Tazk.FrodiVit`. Begge deler blir stående:
    // merkelappen er adressen til nøkkelen i Secure Enclave, ikke en
    // identifikator iOS bryr seg om. Endrer vi den, finner appen ikke igjen
    // nøkkelen, og alt som allerede er forseglet på enheten blir uleselig.
    // Den er privat og vises ingen steder.
    private static let keyTag = "no.Tazk.FrodiKunnskap.vault.v1".data(using: .utf8)!

    enum VaultError: LocalizedError {
        case enclaveUnavailable
        case keyCreationFailed(String)
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .enclaveUnavailable:
                String(localized: "Denne enheten har ingen Secure Enclave.")
            case .keyCreationFailed(let message):
                message
            case .decryptionFailed:
                String(localized: "Innholdet kunne ikke låses opp. Det ble kryptert på en annen enhet.")
            }
        }
    }

    // MARK: - Kryptering

    static func seal(fileAt url: URL) throws -> Data {
        try seal(try Data(contentsOf: url))
    }

    /// Forsegler tekst. Brukes til transkripsjoner, som ofte er mer
    /// eksponerende enn lydfilen: teksten er søkbar og lesbar på et blikk.
    static func seal(_ text: String) throws -> Data {
        try seal(Data(text.utf8))
    }

    static func openText(_ blob: Data) throws -> String {
        guard let text = String(data: try open(blob), encoding: .utf8) else {
            throw VaultError.decryptionFailed
        }
        return text
    }

    static func seal(_ plaintext: Data) throws -> Data {
        let dataKey = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(plaintext, using: dataKey)

        guard let combined = sealed.combined else { throw VaultError.decryptionFailed }
        let wrappedKey = try wrap(dataKey)

        // Format: 2 byte lengde på innpakket nøkkel, nøkkelen, deretter chiffer.
        var out = Data()
        var length = UInt16(wrappedKey.count).bigEndian
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(wrappedKey)
        out.append(combined)
        return out
    }

    static func open(_ blob: Data) throws -> Data {
        guard blob.count > 2 else { throw VaultError.decryptionFailed }
        let length = Int(blob.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        guard blob.count > 2 + length else { throw VaultError.decryptionFailed }

        let wrappedKey = blob.subdata(in: 2..<(2 + length))
        let cipher = blob.subdata(in: (2 + length)..<blob.count)

        let dataKey = try unwrap(wrappedKey)
        let box = try AES.GCM.SealedBox(combined: cipher)
        return try AES.GCM.open(box, using: dataKey)
    }

    // MARK: - Nøkkel i Secure Enclave

    private static func wrap(_ key: SymmetricKey) throws -> Data {
        let privateKey = try enclaveKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw VaultError.keyCreationFailed("Fant ingen offentlig nøkkel.")
        }
        let raw = key.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(
            publicKey, .eciesEncryptionCofactorX963SHA256AESGCM, raw as CFData, &error
        ) else {
            throw VaultError.keyCreationFailed(describe(error))
        }
        return wrapped as Data
    }

    private static func unwrap(_ wrapped: Data) throws -> SymmetricKey {
        let privateKey = try enclaveKey()
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCreateDecryptedData(
            privateKey, .eciesEncryptionCofactorX963SHA256AESGCM, wrapped as CFData, &error
        ) else {
            throw VaultError.decryptionFailed
        }
        return SymmetricKey(data: raw as Data)
    }

    /// Henter nøkkelen, eller lager den første gang.
    private static func enclaveKey() throws -> SecKey {
        if let existing = loadKey() { return existing }
        return try createKey()
    }

    private static func loadKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        guard let result = item else { return nil }
        return (result as! SecKey)
    }

    private static func createKey() throws -> SecKey {
        // whenUnlockedThisDeviceOnly, som er strengere enn i tale til tekst-
        // appen. Der måtte nøkkelen være tilgjengelig med skjermen låst, fordi
        // handlingsknappen kan stoppe et opptak i bakgrunnen. Denne appen gjør
        // ingenting i bakgrunnen: du skriver, laster opp og leser, alt med
        // enheten i hånden og skjermen på. Da skal nøkkelen heller ikke være
        // tilgjengelig når den er låst.
        //
        // Får appen senere arbeid som skal gå i bakgrunnen, er det denne linjen
        // som må vurderes på nytt.
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            &accessError
        ) else {
            throw VaultError.keyCreationFailed(describe(accessError))
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: access
            ]
        ]

        // Simulatoren har ingen Secure Enclave. Da lages nøkkelen i nøkkelringen
        // i stedet, slik at tester og utvikling virker. På enhet er den i Enclave.
        #if !targetEnvironment(simulator)
        attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        #endif

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw VaultError.keyCreationFailed(describe(error))
        }
        return key
    }

    private static func describe(_ error: Unmanaged<CFError>?) -> String {
        guard let error else { return "Ukjent feil." }
        return (error.takeRetainedValue() as Error).localizedDescription
    }
}
