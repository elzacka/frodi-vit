# Security Policy

Fróði vit answers questions on the device. Nothing is transmitted.

Last reviewed 08.09.26.

## Reporting a vulnerability

Email **hei@tazk.no**, subject `[SECURITY] Frodi vit - <description>`.
Include reproduction steps and impact. Acknowledgement within 48 hours,
assessment within 7 days. Do not open public GitHub issues.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Phone lost or stolen, locked | Messages and documents unreadable |
| Backup copied, or restored to another phone | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while the conversation is open | Conversation hidden until capture stops |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Phone unlocked, app open, in someone else's hands | Readable, as with any app |

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

Plaintext exists only while a job runs: while a reply is being generated, while
a document is being read, and while the conversation is on screen.

## No network

The app makes no network requests. Tests fail if an ATS exception appears, if
any background mode is declared at all, or if the privacy manifest declares
collected data.

The language model is bundled and loaded from a local directory. A missing file
fails rather than fetching. `MLXHuggingFace` — the MLX product whose macros
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
