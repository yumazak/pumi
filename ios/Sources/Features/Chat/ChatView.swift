import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel
    @FocusState private var composerFocused: Bool
    @State private var partialCopy: PartialCopyText?
    @State private var footerHeight: CGFloat = 0
    @State private var atBottom = true
    @Environment(\.scenePhase) private var scenePhase

    init(session: OcSession, client: PumiClient) {
        _model = State(initialValue: ChatModel(session: session, client: client))
    }

    var body: some View {
        messageList
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) { footer }
            .onPreferenceChange(FooterHeightKey.self) { footerHeight = $0 }
            .navigationTitle(model.session.title ?? "セッション")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.start() }
            .onDisappear { model.stopListening() }
            #if DEBUG
            // UI screenshots: PUMI_FOCUS_COMPOSER=1 opens with the composer expanded.
            .onAppear {
                if ProcessInfo.processInfo.environment["PUMI_FOCUS_COMPOSER"] == "1" {
                    composerFocused = true
                }
            }
            #endif
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
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.resync() }
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
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                        .onAppear { atBottom = true }
                        .onDisappear { atBottom = false }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, footerHeight + 16, for: .scrollContent)
            .overlay(alignment: .bottomTrailing) {
                if !atBottom {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(.regularMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, footerHeight + 8)
                    .accessibilityLabel("一番下へ")
                }
            }
            .onChange(of: composerFocused) { _, focused in
                guard focused else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: model.messages.count) { _, _ in
                guard atBottom else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: model.liveText) { _, _ in
                guard atBottom else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: model.liveReasoning) { _, _ in
                guard atBottom else { return }
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
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FooterHeightKey.self,
                    value: proxy.size.height
                )
            }
        )
    }
}

/// The composer floats over the thread, so the transcript needs its height as
/// bottom content margin and the glass has something to blur behind it.
private struct FooterHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
