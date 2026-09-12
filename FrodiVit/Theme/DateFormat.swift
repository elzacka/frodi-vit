import Foundation

extension Date {
    /// The date as shown on a conversation: 07.09.26, 00:53
    ///
    /// Same format as in Fróði røst. The year is included because conversations
    /// stay around, and «7. sep.» says nothing about which year it was once the
    /// list has grown.
    var chatStamp: String {
        Self.stampFormatter.string(from: self)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        return formatter
    }()
}
