import Foundation
import Observation

@Observable
@MainActor
final class SessionListModel {
    struct Group: Identifiable {
        var id: String { name }
        var name: String
        var sessions: [OcSession]
    }

    var sessions: [OcSession] = []
    var loading = false
    var error: String?

    private var repoName: [String: String] = [:]

    var groups: [Group] {
        var order: [String] = []
        var byRepo: [String: [OcSession]] = [:]
        for session in sessions {
            let name = repo(for: session)
            if byRepo[name] == nil { order.append(name) }
            byRepo[name, default: []].append(session)
        }
        return order.map { Group(name: $0, sessions: byRepo[$0] ?? []) }
    }

    private func repo(for session: OcSession) -> String {
        if let id = session.projectID, let name = repoName[id] { return name }
        if let directory = session.location?.directory {
            return URL(fileURLWithPath: directory).lastPathComponent
        }
        return "その他"
    }

    func load(client: PumiClient?) async {
        guard let client else {
            error = "設定でサーバ URL を入力してください"
            return
        }
        loading = true
        defer { loading = false }
        do {
            async let sessions = client.sessions()
            async let projects = client.projects()
            self.sessions = try await sessions
            for project in try await projects {
                if let name = project.name { repoName[project.id] = name }
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
