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

    /// Samme format som i Fróði røst. De to appene skal ikke vise datoer ulikt.
    @Test("Vises som dd.MM.yy, HH:mm")
    func usesNorwegianShortFormat() throws {
        #expect(try date("2026-09-07T00:53:00+02:00").chatStamp == "07.09.26, 00:53")
    }

    /// Ledende null, ellers hopper kolonnen i listen.
    @Test("Ledende null på dag og måned")
    func padsSingleDigits() throws {
        #expect(try date("2026-01-05T09:07:00+01:00").chatStamp == "05.01.26, 09:07")
    }

    @Test("24-timers klokke")
    func usesTwentyFourHourClock() throws {
        #expect(try date("2026-09-07T13:05:00+02:00").chatStamp == "07.09.26, 13:05")
    }
}
