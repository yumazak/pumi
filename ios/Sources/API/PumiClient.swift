import Foundation

enum PumiError: LocalizedError {
    case http(Int, String)
    case badURL

    var errorDescription: String? {
        switch self {
        case let .http(status, body):
            return body.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(body)"
        case .badURL:
            return "サーバ URL が不正です"
        }
    }
}

/// The bridge's JSON API. Every call is relative to the configured base URL.
struct PumiClient {
    let baseURL: URL

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }

    private func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw PumiError.badURL }
        guard (200..<300).contains(http.statusCode) else {
            throw PumiError.http(
                http.statusCode,
                String(data: data, encoding: .utf8) ?? ""
            )
        }
    }

    private func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url(path, query: query))
        try check(response, data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

    private func delete(_ path: String) async throws {
        var request = URLRequest(url: url(path))
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

    func sessions(cursor: String? = nil) async throws -> OcSessionsResponse {
        var query: [URLQueryItem] = []
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("/api/sessions", query: query)
    }

    func session(_ sessionID: String) async throws -> OcSession {
        struct Response: Decodable { var data: OcSession }
        let response: Response = try await get("/api/sessions/\(sessionID)")
        return response.data
    }

    func projects() async throws -> [OcProject] {
        struct Response: Decodable { var projects: [OcProject] }
        let response: Response = try await get("/api/projects")
        return response.projects
    }

    func skills(directory: String?) async throws -> [OcSkill] {
        struct Response: Decodable { var data: [OcSkill] }
        var query: [URLQueryItem] = []
        if let directory { query.append(URLQueryItem(name: "directory", value: directory)) }
        let response: Response = try await get("/api/skills", query: query)
        return response.data
    }

    func messages(
        _ sessionID: String,
        limit: Int = 40,
        cursor: String? = nil
    ) async throws -> OcMessagesResponse {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("/api/sessions/\(sessionID)/messages", query: query)
    }

    func prompt(
        _ sessionID: String,
        text: String,
        files: [PromptFile] = [],
        skills: [OcSkill] = [],
        delivery: String?
    ) async throws {
        var body: [String: Any] = ["text": text]
        if let delivery { body["delivery"] = delivery }
        if !files.isEmpty {
            body["files"] = files.map { ["uri": $0.uri, "name": $0.name] }
        }
        if !skills.isEmpty {
            body["skills"] = skills.map { ["id": $0.id] }
        }
        try await post("/api/sessions/\(sessionID)/prompt", body: body)
    }

    func interrupt(_ sessionID: String) async throws {
        try await post("/api/sessions/\(sessionID)/interrupt", body: [:])
    }

    func inbox(_ sessionID: String) async throws -> [OcInboxItem] {
        struct Response: Decodable { var data: [OcInboxItem] }
        let response: Response = try await get("/api/sessions/\(sessionID)/inbox")
        return response.data
    }

    func cancelInbox(_ sessionID: String, item: String) async throws {
        try await delete("/api/sessions/\(sessionID)/inbox/\(item)")
    }

    func permissions(_ sessionID: String) async throws -> [OcPermission] {
        struct Response: Decodable { var data: [OcPermission] }
        let response: Response = try await get("/api/sessions/\(sessionID)/permissions")
        return response.data
    }

    func forms(_ sessionID: String) async throws -> [OcForm] {
        struct Response: Decodable { var data: [OcForm] }
        let response: Response = try await get("/api/sessions/\(sessionID)/forms")
        return response.data
    }

    func replyPermission(
        _ sessionID: String,
        request: String,
        decision: String
    ) async throws {
        try await post(
            "/api/sessions/\(sessionID)/permissions/\(request)/reply",
            body: ["decision": decision]
        )
    }

    func replyForm(
        _ sessionID: String,
        form: String,
        answer: [String: Any]
    ) async throws {
        try await post(
            "/api/sessions/\(sessionID)/forms/\(form)/reply",
            body: ["answer": answer]
        )
    }

    func view(_ sessionID: String, idle: Double) async throws {
        try await post("/api/sessions/\(sessionID)/view", body: ["idle": idle])
    }

    /// The session's SSE stream, one decoded event at a time.
    func events(_ sessionID: String) -> AsyncThrowingStream<OcEvent, Error> {
        let url = url("/api/events", query: [URLQueryItem(name: "session", value: sessionID)])
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 60 * 60
                    request.setValue("text/event-stream", forHTTPHeaderField: "accept")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw PumiError.badURL
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw PumiError.http(http.statusCode, "")
                    }
                    var payload = ""
                    for try await line in bytes.lines {
                        if line.isEmpty {
                            if let data = payload.data(using: .utf8),
                               let event = try? JSONDecoder().decode(OcEvent.self, from: data) {
                                continuation.yield(event)
                            }
                            payload = ""
                        } else if line.hasPrefix("data:") {
                            payload += line.dropFirst(5)
                                .trimmingCharacters(in: .whitespaces)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
