import Foundation

enum Format {
    static func relative(_ milliseconds: Double?) -> String {
        guard let milliseconds else { return "" }
        let date = Date(timeIntervalSince1970: milliseconds / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// A session is unread when it has finished a turn the viewer has not seen.
    static func isUnread(_ session: OcSession) -> Bool {
        guard let idle = session.time?.idle else { return false }
        guard let viewed = session.time?.viewed else { return true }
        return idle > viewed
    }
}
