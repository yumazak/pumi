import Foundation
import Observation

/// Where the bridge lives. A device uses the tailnet HTTPS URL; the simulator
/// can use `http://127.0.0.1:7180`.
@Observable
final class Settings {
    private static let key = "baseURL"

    var baseURLText: String {
        didSet { UserDefaults.standard.set(baseURLText, forKey: Self.key) }
    }

    init() {
        baseURLText =
            UserDefaults.standard.string(forKey: Self.key) ?? "http://127.0.0.1:7180"
    }

    var client: PumiClient? {
        guard let url = URL(string: baseURLText), url.scheme != nil else {
            return nil
        }
        return PumiClient(baseURL: url)
    }
}
