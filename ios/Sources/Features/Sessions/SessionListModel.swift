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
    var loadingMore = false
    var error: String?

    private var repoName: [String: String] = [:]
    private var cursor: String?

    var hasMore: Bool { cursor != nil }

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

    /// The groups filtered by a query: a matching project name keeps the whole
    /// group, otherwise only the sessions whose title, directory or agent match.
    func groups(matching query: String) -> [Group] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return groups }
        return groups.compactMap { group in
            if group.name.localizedCaseInsensitiveContains(text) { return group }
            let matches = group.sessions.filter { session in
                (session.title ?? "").localizedCaseInsensitiveContains(text)
                    || (session.location?.directory ?? "").localizedCaseInsensitiveContains(text)
                    || (session.agent ?? "").localizedCaseInsensitiveContains(text)
            }
            return matches.isEmpty ? nil : Group(name: group.name, sessions: matches)
        }
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
            async let page = client.sessions()
            async let projects = client.projects()
            let first = try await page
            sessions = first.sessions
            cursor = first.cursor?.next
            for project in try await projects {
                if let name = project.name { repoName[project.id] = name }
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The list pages through opencode's cursor as the reader reaches the end.
    func loadMore(client: PumiClient?) async {
        guard let client, let cursor, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await client.sessions(cursor: cursor)
            let known = Set(sessions.map(\.id))
            sessions += page.sessions.filter { !known.contains($0.id) }
            self.cursor = page.cursor?.next
        } catch {
            self.error = error.localizedDescription
        }
    }
}
