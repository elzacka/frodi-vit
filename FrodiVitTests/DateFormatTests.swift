import Foundation
import Testing
@testable import FrodiVit

@Suite("Datoformat")
struct DateFormatTests {
    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Oslo")
        formatter.formatOptions = [.withInternetDateTime]
        return try #require(formatter.date(from: iso))
    }

    /// Same format as in Fróði røst. The two apps must not show dates differently.
    @Test("Vises som dd.MM.yy, HH:mm")
    func usesNorwegianShortFormat() throws {
        #expect(try date("2026-09-07T00:53:00+02:00").chatStamp == "07.09.26, 00:53")
    }

    /// Leading zero, or the column in the list jumps.
    @Test("Ledende null på dag og måned")
    func padsSingleDigits() throws {
        #expect(try date("2026-01-05T09:07:00+01:00").chatStamp == "05.01.26, 09:07")
    }

    @Test("24-timers klokke")
    func usesTwentyFourHourClock() throws {
        #expect(try date("2026-09-07T13:05:00+02:00").chatStamp == "07.09.26, 13:05")
    }
}
