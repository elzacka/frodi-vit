#!/usr/bin/env swift

// Prints what App Store Connect actually holds for Fróði vit, so the
// live version is never guessed from the repo. Run before touching
// MARKETING_VERSION or CURRENT_PROJECT_VERSION.
//
//   swift Scripts/asc-status.swift
//
// Credentials, both outside the repo:
//   ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8   (key id read from the filename)
//   ~/.appstoreconnect/issuer_id                          (or the ASC_ISSUER_ID environment variable)

import CryptoKit
import Foundation

// MARK: - Config

let bundleId = "com.Tazk.FrodiVit"
let apiHost = "https://api.appstoreconnect.apple.com"
let home = FileManager.default.homeDirectoryForCurrentUser
let keyDirectory = home.appendingPathComponent(".appstoreconnect/private_keys")
let issuerFile = home.appendingPathComponent(".appstoreconnect/issuer_id")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Feil: \(message)\n".utf8))
    exit(1)
}

// MARK: - Credentials

let keyFiles = (try? FileManager.default.contentsOfDirectory(at: keyDirectory, includingPropertiesForKeys: nil))?
    .filter { $0.lastPathComponent.hasPrefix("AuthKey_") && $0.pathExtension == "p8" } ?? []

guard let keyFile = keyFiles.first else {
    fail("""
    fant ingen AuthKey_*.p8 i \(keyDirectory.path)
    Last ned en App Store Connect API-nøkkel og legg den der.
    """)
}

let keyId = keyFile.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "AuthKey_", with: "")

let issuerId: String = {
    if let env = ProcessInfo.processInfo.environment["ASC_ISSUER_ID"], !env.isEmpty { return env }
    if let file = try? String(contentsOf: issuerFile, encoding: .utf8) {
        let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
    }
    fail("""
    mangler Issuer ID.
    Hent den i App Store Connect: Users and Access -> Integrations -> App Store Connect API.
    Lagre den så: echo '<issuer-id>' > \(issuerFile.path)
    """)
}()

guard let pem = try? String(contentsOf: keyFile, encoding: .utf8),
      let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
    fail("kunne ikke lese privatnøkkelen i \(keyFile.path)")
}

// MARK: - JWT

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeToken() -> String {
    let now = Int(Date().timeIntervalSince1970)
    let header: [String: Any] = ["alg": "ES256", "kid": keyId, "typ": "JWT"]
    let payload: [String: Any] = [
        "iss": issuerId,
        "iat": now,
        "exp": now + 900,
        "aud": "appstoreconnect-v1",
    ]

    guard let headerData = try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]),
          let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
        fail("kunne ikke bygge JWT")
    }

    let signingInput = "\(base64URL(headerData)).\(base64URL(payloadData))"
    guard let signature = try? privateKey.signature(for: Data(signingInput.utf8)) else {
        fail("kunne ikke signere JWT")
    }
    return "\(signingInput).\(base64URL(signature.rawRepresentation))"
}

let token = makeToken()

// MARK: - Requests

/// Synchronous GET — this is a script, and a semaphore keeps the flow readable.
func get(_ path: String) -> [String: Any] {
    guard let url = URL(string: apiHost + path) else { fail("ugyldig URL: \(path)") }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30

    var result: [String: Any] = [:]
    var failure: String?
    let semaphore = DispatchSemaphore(value: 0)

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error {
            failure = "nettverksfeil: \(error.localizedDescription)"
            return
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let data else {
            failure = "tomt svar (HTTP \(status))"
            return
        }
        guard status == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let hint = status == 401
                ? "\nSjekk at Issuer ID og nøkkel-ID (\(keyId)) hører sammen, og at nøkkelen ikke er trukket tilbake."
                : ""
            failure = "HTTP \(status) for \(path)\(hint)\n\(body.prefix(400))"
            return
        }
        result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }.resume()

    semaphore.wait()
    if let failure { fail(failure) }
    return result
}

func rows(_ json: [String: Any]) -> [[String: Any]] {
    json["data"] as? [[String: Any]] ?? []
}

func attributes(_ row: [String: Any]) -> [String: Any] {
    row["attributes"] as? [String: Any] ?? [:]
}

// MARK: - Fetch

let apps = rows(get("/v1/apps?filter[bundleId]=\(bundleId)"))
guard let app = apps.first, let appId = app["id"] as? String else {
    fail("fant ingen app med bundle-ID \(bundleId) på denne kontoen")
}

let versions = rows(get("/v1/apps/\(appId)/appStoreVersions?limit=20"))

let buildsJSON = get("/v1/builds?filter[app]=\(appId)&limit=20&sort=-uploadedDate&include=preReleaseVersion")
let builds = rows(buildsJSON)
let included = buildsJSON["included"] as? [[String: Any]] ?? []

/// Build rows carry only the build number; the marketing version lives on the
/// related preReleaseVersion, which is why the request asks for it to be included.
var preReleaseVersions: [String: String] = [:]
for item in included where item["type"] as? String == "preReleaseVersions" {
    if let id = item["id"] as? String, let version = attributes(item)["version"] as? String {
        preReleaseVersions[id] = version
    }
}

func marketingVersion(of build: [String: Any]) -> String {
    guard let relationships = build["relationships"] as? [String: Any],
          let relation = relationships["preReleaseVersion"] as? [String: Any],
          let data = relation["data"] as? [String: Any],
          let id = data["id"] as? String else { return "?" }
    return preReleaseVersions[id] ?? "?"
}

// MARK: - Report

let live = versions.first { attributes($0)["appStoreState"] as? String == "READY_FOR_SALE" }
let pending = versions.first {
    let state = attributes($0)["appStoreState"] as? String ?? ""
    return state != "READY_FOR_SALE" && state != "REPLACED_WITH_NEW_VERSION"
}

func pad(_ label: String) -> String {
    label.padding(toLength: 20, withPad: " ", startingAt: 0)
}

print("")
print(pad("Live i App Store:") + (live.map { attributes($0)["versionString"] as? String ?? "?" } ?? "ingen sluppet versjon"))

if let pending {
    let attrs = attributes(pending)
    let version = attrs["versionString"] as? String ?? "?"
    let state = attrs["appStoreState"] as? String ?? "?"
    print(pad("Under behandling:") + "\(version) — \(state)")
}

if let latest = builds.first {
    let attrs = attributes(latest)
    let number = attrs["version"] as? String ?? "?"
    let state = attrs["processingState"] as? String ?? "?"
    print(pad("Siste opplasting:") + "\(marketingVersion(of: latest)) (build \(number)) — \(state)")

    let nextBuild = builds
        .compactMap { Int(attributes($0)["version"] as? String ?? "") }
        .max()
        .map { $0 + 1 }
    print(pad("Neste build:") + (nextBuild.map(String.init) ?? "?"))
} else {
    print(pad("Siste opplasting:") + "ingen builds")
}

// MARK: - Compare with the repo

let projectYML = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("project.yml")

if let yml = try? String(contentsOf: projectYML, encoding: .utf8) {
    func setting(_ key: String) -> String? {
        for line in yml.split(separator: "\n") where line.contains("\(key):") {
            return line.split(separator: ":").last?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        }
        return nil
    }

    let repoVersion = setting("MARKETING_VERSION") ?? "?"
    let repoBuild = setting("CURRENT_PROJECT_VERSION") ?? "?"
    print("")
    print(pad("I project.yml:") + "\(repoVersion) (build \(repoBuild))")

    let uploadedBuilds = Set(builds.compactMap { attributes($0)["version"] as? String })
    if uploadedBuilds.contains(repoBuild) {
        print(pad("") + "Build \(repoBuild) er allerede lastet opp. Bump CURRENT_PROJECT_VERSION før arkivering.")
        print("")
        // Exit code 2 stops a release flow before archiving a build number
        // App Store Connect will reject.
        exit(2)
    }
}

print("")
