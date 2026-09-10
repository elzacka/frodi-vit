import Foundation

extension Date {
    /// Datoen slik den vises på en samtale: 07.09.26, 00:53
    ///
    /// Samme format som i Fróði røst. Året er med fordi samtaler blir
    /// liggende, og «7. sep.» sier ingenting om hvilket år det var når listen
    /// har vokst.
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
