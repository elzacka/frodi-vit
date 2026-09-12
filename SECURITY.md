# Security Policy

Fróði vit answers questions on the device. Nothing is transmitted.

Last reviewed 13.09.26.

## Reporting a vulnerability

Email **hei@tazk.no**, subject `[SECURITY] Fróði vit - <description>`.
Include reproduction steps and impact. Acknowledgement within 48 hours,
assessment within 7 days. Do not open public GitHub issues.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Device lost or stolen, locked | Messages and documents unreadable |
| Backup copied, or restored to another device | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while the conversation is open | Conversation hidden until capture stops |
| App switcher, or any other time the app is not in front | Conversation hidden before iOS takes the snapshot |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Device unlocked, app open, in someone else's hands | Readable, as with any app |

## What is in use

Every security technology and setting the app relies on, and where it lives.
The sections below explain the choices.

| Area | Technology or setting | Where |
|---|---|---|
| Isolation | iOS app sandbox. No app group, no shared container | System |
| Encryption at rest | AES-GCM, one random 256-bit key per message, per chat title and per document | `Vault` |
| Key wrapping | P-256 key created in the Secure Enclave, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | `Vault` |
| File protection | The system default for the container, `NSFileProtectionCompleteUntilFirstUserAuthentication`. Nothing stricter is set, because the sealed fields do not depend on it | System |
| Backup | `isExcludedFromBackup` on the SwiftData store (`.store`, `-wal`, `-shm`), re-applied on every launch | `Storage` |
| Writing Tools | `.writingToolsBehavior(.disabled)` on the input field, so the system cannot send a draft to Private Cloud Compute or an external model from inside the app | `ChatView` |
| Transport | None. No `URLSession`, no `NSAppTransportSecurity` exceptions | `Info.plist`, `IsolationTests` |
| Background | No `UIBackgroundModes` at all, tested absent | `Info.plist`, `IsolationTests` |
| Permissions | None. No usage-description keys; microphone and speech keys are tested absent | `Info.plist`, `IsolationTests` |
| Document upload | The system file picker, which grants access to the one file chosen. The text is sealed on import and the file is not kept | `DocumentImport` |
| Language models | Both bundled and loaded from local directories. `MLXHuggingFace` is not linked, so no code path reaches the Hugging Face hub | `project.yml`, `BorealisAssistant`, `BorealisEmbedder` |
| Privacy manifest | No tracking, no tracking domains, no collected data. One accessed API: file timestamps, C617.1 | `PrivacyInfo.xcprivacy`, `IsolationTests` |
| Screen capture | Conversation hidden while `UIScreen.isCaptured` is true, and while the scene is not active | `CaptureGuard` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave | `project.yml` |
| Compiler | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true` | `project.yml` |
| Attack surface kept closed | No URL schemes, no document types, no `NSUserActivity` (Handoff), no Spotlight indexing, no extensions, no app group | `Info.plist` |

## Encryption

Every message and uploaded document is sealed with AES-GCM under a per-item
256-bit key. That key is wrapped by a P-256 key created inside the Secure
Enclave. The private key cannot be extracted.

Access control is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

- **WhenUnlocked**, not AfterFirstUnlock. This is stricter than the dictaphone
  app, which needs the key while the screen is locked because the Action Button
  can stop a recording in the background. This app does nothing in the
  background, so the key has no reason to be available while locked.
- **ThisDeviceOnly**: the key is excluded from backups and device migration.

What you ask often reveals more than the answer does, so the question is sealed
on the same terms as the answer.

An uploaded document is split into passages, and each passage is sealed on the
same terms as the document. The 768-float embedding stored beside each passage
is not sealed: it is not text and cannot be turned back into text, and opening
every one of them for every question would cost more than it protects. The
document names an answer cites are stored in plain, as document names already
are.

Plaintext exists only while a job runs: while a reply is being generated, while
a document is being read, and while the conversation is on screen.

The SwiftData store is marked `isExcludedFromBackup` at every launch. Apple
documents the flag as resettable guidance, so it is re-applied rather than set
once. The messages in the store are ciphertext, but the dates and the number of
chats and messages are not, and none of that belongs in a backup. Encryption is
what carries the guarantee.

## Apple Intelligence

Writing Tools is disabled on the input field. It is the one place the system
itself could send what you typed off the device from inside the app: a request
the on-device model cannot handle goes to Private Cloud Compute, and with an
external integration switched on, further. The field holds a question, not a
document, so nothing is lost by switching it off.

## No network

The app makes no network requests. Tests fail if an ATS exception appears, if
any background mode is declared at all, or if the privacy manifest declares
collected data.

Both language models are bundled and loaded from local directories. A missing
file fails rather than fetching. `MLXHuggingFace` — the MLX product whose macros
expand into Hugging Face hub calls — is deliberately not linked.

**One honest qualification.** The tokenizer comes from `swift-transformers`,
whose `Tokenizers` target depends on its `Hub` target, which depends on
`swift-huggingface`. So HTTP client code is *linked into the binary* even
though nothing in this app calls it: the only tokenizer entry point used is
`AutoTokenizer.from(modelFolder:)`, which reads local files.

The precise claim is therefore "this app makes no network requests", not "this
binary contains no networking code". The second would be stronger and is not
true. Making it true would mean writing a BPE tokenizer and a Jinja chat-template
renderer by hand, which is a real cost for a guarantee the sandbox, the absent
ATS exceptions and the absent background modes already carry in practice.

`PrivacyInfo.xcprivacy` declares no tracking, no tracking domains, no collected
data types. The only accessed-API declaration is file timestamps (C617.1).

## Permissions

None. The app requests no microphone, no camera, no contacts, no location.
Document upload goes through the system file picker, which grants access to the
one file you pick and nothing else.

A test fails if `NSMicrophoneUsageDescription` or
`NSSpeechRecognitionUsageDescription` appears — both belong to the other app.

## Dependencies

MLX Swift, listed in [TREDJEPART.md](TREDJEPART.md). None performs network
access as configured.

## Model licensing

`borealis-open-1b` is under the Gemma Terms of Use. `borealis-embed-212m` is
under NB-License 1.0, which is source-available rather than OSI-open and carries
use-based restrictions. Neither restriction applies to this app; the reasoning
is in [TREDJEPART.md](TREDJEPART.md).

## Deliberate omissions

- **No biometric lock.** The device passcode already gates the encryption key.
  A second gate inside the app would add friction without adding protection.
- **No certificate pinning.** There is no transport.
- **No screenshot blocking.** `userDidTakeScreenshotNotification` fires after the
  image exists. The hidden `isSecureTextEntry` trick is undocumented and can break
  without warning. The app does not offer what it cannot deliver.
