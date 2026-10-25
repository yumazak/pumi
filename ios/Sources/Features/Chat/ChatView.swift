import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel
    @FocusState private var composerFocused: Bool
    @State private var partialCopy: PartialCopyText?

    init(session: OcSession, client: PumiClient) {
        _model = State(initialValue: ChatModel(session: session, client: client))
    }

    var body: some View {
        messageList
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .navigationTitle(model.session.title ?? "セッション")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.start() }
            .onDisappear { model.stopListening() }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { model.error != nil },
                    set: { if !$0 { model.error = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.error = nil }
            } message: {
                Text(model.error ?? "")
            }
            .sheet(item: $partialCopy) { copy in
                PartialCopyView(text: copy.text)
            }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    // The top sentinel pulls the previous page. Scrolling back
                    // to the message the reader was on keeps the position.
                    if model.cursor != nil {
                        Color.clear
                            .frame(height: 8)
                            .onAppear {
                                let anchor = model.messages.first?.id
                                Task {
                                    await model.loadOlder()
                                    if let anchor {
                                        proxy.scrollTo(anchor, anchor: .top)
                                    }
                                }
                            }
                    }
                    if model.loadingOlder {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    ForEach(model.messages) { message in
                        MessageView(message: message) { text in
                            partialCopy = PartialCopyText(text: text)
                        }
                        .id(message.id)
                    }
                    if let pending = model.pendingUserText {
                        UserBubble(text: pending).id("pending")
                    }
                    if model.running || !model.liveText.isEmpty
                        || !model.liveReasoning.isEmpty {
                        LiveMessage(
                            text: model.liveText,
                            reasoning: model.liveReasoning,
                            running: model.running
                        )
                        .id("live")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: composerFocused) { _, focused in
                guard focused else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: model.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: model.liveText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: model.liveReasoning) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !model.inbox.isEmpty { InboxBar(model: model) }
            if !model.permissions.isEmpty { PermissionBar(model: model) }
            if !model.forms.isEmpty { FormBar(model: model) }
            if !model.attachments.isEmpty || !model.attachedSkills.isEmpty {
                AttachmentChips(model: model)
            }
            Composer(model: model, focused: $composerFocused)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
}
