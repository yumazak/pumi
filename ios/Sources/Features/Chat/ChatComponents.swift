import MarkdownUI
import SwiftUI

struct MessageView: View {
    let message: OcMessage

    var body: some View {
        switch message.type {
        case "user":
            UserBubble(text: userText)
        case "assistant":
            AssistantMessage(parts: message.content ?? [])
        case "skill":
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private var userText: String {
        var lines: [String] = []
        if let text = message.text, !text.isEmpty { lines.append(text) }
        let skills = (message.skills ?? []).compactMap { $0.name ?? $0.id }
        if !skills.isEmpty {
            lines.append(skills.map { "🧩 \($0)" }.joined(separator: "\n"))
        }
        let files = (message.files ?? []).compactMap(\.name)
        if !files.isEmpty {
            lines.append(files.map { "📎 \($0)" }.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }
}

struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: 18)
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .textSelection(.enabled)
    }
}

struct AssistantMessage: View {
    let parts: [OcContentPart]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part.type {
                case "reasoning":
                    ReasoningView(text: part.text ?? "")
                case "tool":
                    ToolView(part: part)
                default:
                    if let text = part.text, !text.isEmpty {
                        Markdown(text).markdownTheme(.pumi)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Reasoning stays collapsed until the reader opens it.
struct ReasoningView: View {
    let text: String
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label("推論", systemImage: "brain")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
    }
}

struct ToolView: View {
    let part: OcContentPart
    @State private var open = false

    private var result: String {
        (part.state?.content ?? []).compactMap(\.text).joined(separator: "\n")
    }

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            if result.isEmpty {
                Text("実行中…").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        } label: {
            Label(part.name ?? "tool", systemImage: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LiveMessage: View {
    let text: String
    let reasoning: String
    let running: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !reasoning.isEmpty { ReasoningView(text: reasoning) }
            if text.isEmpty {
                if running { ThinkingDots() }
            } else {
                // Plain text while streaming: re-parsing Markdown on every delta
                // makes code-block backgrounds flash and the layout jump. The
                // finished message renders through Markdown.
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1 : 0.3)
            }
        }
        .foregroundStyle(.secondary)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                phase = (phase + 1) % 3
            }
        }
    }
}

struct InboxBar: View {
    @Bindable var model: ChatModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("送信待ち")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(model.inbox.filter { $0.type == "user" }) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.payload?.text ?? "")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Task { await model.cancelInbox(item) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(
                    .quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
    }
}

struct PermissionBar: View {
    @Bindable var model: ChatModel

    var body: some View {
        ForEach(model.permissions) { permission in
            VStack(alignment: .leading, spacing: 8) {
                Text(permission.action ?? "許可")
                    .font(.subheadline.weight(.semibold))
                if let message = permission.message, !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("許可") {
                        Task { await model.reply(permission, "once") }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("常に許可") {
                        Task { await model.reply(permission, "always") }
                    }
                    .buttonStyle(.bordered)
                    Button("拒否", role: .destructive) {
                        Task { await model.reply(permission, "reject") }
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .quaternary.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

struct FormBar: View {
    @Bindable var model: ChatModel

    var body: some View {
        ForEach(model.forms) { form in
            FormCard(form: form) { answer in
                Task { await model.reply(form: form, answer: answer) }
            }
        }
    }
}

struct FormCard: View {
    let form: OcForm
    let onReply: ([String: Any]) -> Void

    @State private var strings: [String: String] = [:]
    @State private var bools: [String: Bool] = [:]
    @State private var lists: [String: Set<String>] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(form.title ?? "質問")
                .font(.subheadline.weight(.semibold))
            ForEach(form.fields) { field in
                fieldView(field)
            }
            Button("回答") { onReply(answer()) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func fieldView(_ field: OcFormField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.title ?? field.key)
                .font(.caption)
                .foregroundStyle(.secondary)
            if field.type == "boolean" {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { bools[field.key] ?? false },
                        set: { bools[field.key] = $0 }
                    )
                )
                .labelsHidden()
            } else if let options = field.options, !options.isEmpty {
                if field.type == "multiselect" {
                    ForEach(options, id: \.value) { option in
                        Toggle(
                            option.label ?? option.value,
                            isOn: Binding(
                                get: { lists[field.key, default: []].contains(option.value) },
                                set: { on in
                                    var selected = lists[field.key, default: []]
                                    if on {
                                        selected.insert(option.value)
                                    } else {
                                        selected.remove(option.value)
                                    }
                                    lists[field.key] = selected
                                }
                            )
                        )
                    }
                } else {
                    Picker(
                        "",
                        selection: Binding(
                            get: { strings[field.key] ?? options[0].value },
                            set: { strings[field.key] = $0 }
                        )
                    ) {
                        ForEach(options, id: \.value) { option in
                            Text(option.label ?? option.value).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                TextField(
                    "",
                    text: Binding(
                        get: { strings[field.key] ?? "" },
                        set: { strings[field.key] = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .keyboardType(
                    field.type == "number" || field.type == "integer"
                        ? .numbersAndPunctuation : .default
                )
            }
        }
    }

    private func answer() -> [String: Any] {
        var out: [String: Any] = [:]
        for field in form.fields {
            switch field.type {
            case "boolean":
                out[field.key] = bools[field.key] ?? false
            case "number", "integer":
                if let text = strings[field.key], let number = Double(text) {
                    out[field.key] = number
                }
            case "multiselect":
                out[field.key] = Array(lists[field.key] ?? [])
            default:
                if let options = field.options, !options.isEmpty {
                    out[field.key] = strings[field.key] ?? options[0].value
                } else if let text = strings[field.key], !text.isEmpty {
                    out[field.key] = text
                }
            }
        }
        return out
    }
}

struct Composer: View {
    @Bindable var model: ChatModel
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("返信を入力…", text: $model.draft, axis: .vertical)
                .focused($focused)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    .quaternary.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 18)
                )
            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(
                model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.sending
            )
        }
    }
}
