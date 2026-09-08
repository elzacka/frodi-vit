import Foundation

/// Om basen lot seg åpne.
///
/// Gikk det galt, kjører appen videre på minnet. Den virker da helt som
/// vanlig fram til du lukker den, og så er samtalen borte. En stille feil er
/// verre enn en synlig, så skjermen sier fra.
@MainActor
enum Storage {
    private(set) static var failed = false

    static func markFailed() {
        failed = true
    }
}
