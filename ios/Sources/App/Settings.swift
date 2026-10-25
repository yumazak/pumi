import Foundation
import Observation

/// Where the bridge lives. A device uses the tailnet HTTPS URL; the simulator
/// can use `http://127.0.0.1:7180`.
@Observable
final class Settings {
    private static let key = "baseURL"
    private static let streamingKey = "streaming"

    var baseURLText: String {
        didSet { UserDefaults.standard.set(baseURLText, forKey: Self.key) }
    }

    /// When off, SSE still keeps the chat current but the reply appears in one
    /// piece at the end instead of growing token by token.
    var streaming: Bool {
        didSet { UserDefaults.standard.set(streaming, forKey: Self.streamingKey) }
    }

    init() {
        baseURLText =
            UserDefaults.standard.string(forKey: Self.key) ?? "http://127.0.0.1:7180"
        streaming = UserDefaults.standard.object(forKey: Self.streamingKey) as? Bool ?? true
    }

    var client: PumiClient? {
        guard let url = URL(string: baseURLText), url.scheme != nil else {
            return nil
        }
        return PumiClient(baseURL: url)
    }
}
