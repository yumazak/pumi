import Foundation
import Observation

@Observable
@MainActor
final class ChatModel {
    let session: OcSession
    private let client: PumiClient

    var messages: [OcMessage] = []
    var inbox: [OcInboxItem] = []
    var permissions: [OcPermission] = []
    var forms: [OcForm] = []
    var running = false
    var liveText = ""
    var liveReasoning = ""
    var cursor: String?
    var loading = false
    var loadingOlder = false
    var error: String?
    var draft = ""
    var sending = false
    var pendingUserText: String?
    var attachments: [PromptFile] = []
    var attachedSkills: [OcSkill] = []

    private var events: Task<Void, Never>?
    private var textBuffer = ""
    private var reasoningBuffer = ""
    private var flushTask: Task<Void, Never>?

    init(session: OcSession, client: PumiClient) {
        self.session = session
        self.client = client
    }

    func start() async {
        await reload()
        guard events == nil else { return }
        events = Task { await listen() }
    }

    func stopListening() {
        events?.cancel()
        events = nil
    }

    /// The app was in the background: the stream may be dead and messages may
    /// have arrived from another client. Reload and reconnect.
    func resync() async {
        await reload()
        events?.cancel()
        events = Task { await listen() }
    }

    func reload() async {
        loading = messages.isEmpty
        defer { loading = false }
        do {
            let page = try await client.messages(session.id, limit: 40)
            merge(page.data)
            cursor = page.cursor?.next
            inbox = try await client.inbox(session.id)
            permissions = try await client.permissions(session.id)
            forms = try await client.forms(session.id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if let idle = session.time?.idle, Format.isUnread(session) {
            try? await client.view(session.id, idle: idle)
        }
    }

    func loadOlder() async {
        guard !loadingOlder, let cursor else { return }
        loadingOlder = true
        defer { loadingOlder = false }
        do {
            let page = try await client.messages(session.id, limit: 40, cursor: cursor)
            self.cursor = page.cursor?.next
            let known = Set(messages.map(\.id))
            messages = page.data.filter { !known.contains($0.id) } + messages
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A prompt sent while a turn is running joins opencode's inbox; otherwise
    /// it starts a turn and gets a local stand-in until the server has it.
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachments.isEmpty, !sending else { return }
        sending = true
        defer { sending = false }
        let files = attachments
        let skills = attachedSkills
        let delivery = running ? "queue" : nil
        do {
            try await client.prompt(
                session.id,
                text: text,
                files: files,
                skills: skills,
                delivery: delivery
            )
            draft = ""
            attachments = []
            attachedSkills = []
            if delivery == nil {
                pendingUserText = note(text, files: files, skills: skills)
                await refreshMessages()
            } else {
                await refreshInbox()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func interrupt() async {
        do {
            try await client.interrupt(session.id)
            await refreshMessages()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addAttachment(_ file: PromptFile) {
        attachments.append(file)
    }

    func removeAttachment(_ file: PromptFile) {
        attachments.removeAll { $0.id == file.id }
    }

    func toggleSkill(_ skill: OcSkill) {
        if let index = attachedSkills.firstIndex(where: { $0.id == skill.id }) {
            attachedSkills.remove(at: index)
        } else {
            attachedSkills.append(skill)
        }
    }

    func removeSkill(_ skill: OcSkill) {
        attachedSkills.removeAll { $0.id == skill.id }
    }

    func availableSkills() async -> [OcSkill] {
        (try? await client.skills(directory: session.location?.directory)) ?? []
    }

    private func note(_ text: String, files: [PromptFile], skills: [OcSkill]) -> String {
        var lines = [text]
        lines += skills.map { "🧩 \($0.name ?? $0.id)" }
        lines += files.map { "📎 \($0.name)" }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    func cancelInbox(_ item: OcInboxItem) async {
        inbox.removeAll { $0.id == item.id }
        try? await client.cancelInbox(session.id, item: item.id)
        await refreshInbox()
    }

    func reply(_ permission: OcPermission, _ decision: String) async {
        do {
            try await client.replyPermission(
                session.id,
                request: permission.id,
                decision: decision
            )
            await refreshDock()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reply(form: OcForm, answer: [String: Any]) async {
        do {
            try await client.replyForm(session.id, form: form.id, answer: answer)
            await refreshDock()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func merge(_ page: [OcMessage]) {
        var fresh: [String: OcMessage] = [:]
        for message in page { fresh[message.id] = message }
        let known = Set(messages.map(\.id))
        messages = messages.map { fresh[$0.id] ?? $0 }
            + page.filter { !known.contains($0.id) }
        if let pendingUserText,
           page.contains(where: { $0.type == "user" && $0.text == pendingUserText }) {
            self.pendingUserText = nil
        }
    }

    private func refreshMessages() async {
        if let page = try? await client.messages(session.id, limit: 40) {
            merge(page.data)
            cursor = page.cursor?.next ?? cursor
        }
    }

    private func refreshInbox() async {
        if let items = try? await client.inbox(session.id) { inbox = items }
    }

    private func refreshDock() async {
        if let items = try? await client.permissions(session.id) { permissions = items }
        if let items = try? await client.forms(session.id) { forms = items }
    }

    private func listen() async {
        while !Task.isCancelled {
            do {
                for try await event in client.events(session.id) {
                    if Task.isCancelled { return }
                    handle(event)
                }
            } catch {
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func handle(_ event: OcEvent) {
        switch event.type {
        case "session.execution.started":
            running = true
        case "session.execution.succeeded", "session.execution.failed",
             "session.execution.interrupted":
            running = false
        case "session.text.started":
            flushTask?.cancel()
            flushTask = nil
            textBuffer = ""
            liveText = ""
        case "session.text.delta":
            textBuffer += event.data?.delta ?? ""
            scheduleFlush()
        case "session.text.ended":
            flushTask?.cancel()
            flushTask = nil
            textBuffer = event.data?.text ?? textBuffer
            liveText = textBuffer
        case "session.reasoning.started":
            flushTask?.cancel()
            flushTask = nil
            reasoningBuffer = ""
            liveReasoning = ""
        case "session.reasoning.delta":
            reasoningBuffer += event.data?.delta ?? ""
            scheduleFlush()
        case "session.reasoning.ended":
            flushTask?.cancel()
            flushTask = nil
            reasoningBuffer = event.data?.text ?? reasoningBuffer
            liveReasoning = reasoningBuffer
        case "session.step.ended":
            Task {
                await refreshMessages()
                flushTask?.cancel()
                flushTask = nil
                textBuffer = ""
                reasoningBuffer = ""
                liveText = ""
                liveReasoning = ""
                pendingUserText = nil
            }
        default:
            let type = event.type
            if type.hasPrefix("session.inbox.") {
                Task { await refreshInbox() }
                if type == "session.inbox.delivered" {
                    Task { await refreshMessages() }
                }
            } else if type.hasPrefix("permission.") || type.hasPrefix("form.") {
                Task { await refreshDock() }
            }
        }
    }

    /// Deltas arrive many times a second; applying every one re-renders the
    /// transcript constantly. Coalesce them into ~12 updates a second.
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard let self, !Task.isCancelled else { return }
            self.liveText = self.textBuffer
            self.liveReasoning = self.reasoningBuffer
            self.flushTask = nil
        }
    }
}
