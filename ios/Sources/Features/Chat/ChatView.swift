import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel

    init(session: OcSession, client: PumiClient) {
        _model = State(initialValue: ChatModel(session: session, client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            footer
        }
        .navigationTitle(model.session.title ?? "セッション")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
        .onDisappear { model.stop() }
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
                        MessageView(message: message).id(message.id)
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
            Composer(model: model)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
