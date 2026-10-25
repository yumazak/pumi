import SwiftUI

struct ChatView: View {
    @State private var model: ChatModel
    @FocusState private var composerFocused: Bool
    @State private var partialCopy: PartialCopyText?
    /// Set when the reader scrolls away from the bottom; cleared when they
    /// return. Auto-follow stops while this is true.
    @State private var scrolledUp = false
    @State private var footerHeight: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    init(session: OcSession, client: PumiClient) {
        _model = State(initialValue: ChatModel(session: session, client: client))
    }

    var body: some View {
        messageList
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) { footer }
            .overlay {
                if model.loading && model.messages.isEmpty {
                    ProgressView()
                }
            }
            .onPreferenceChange(FooterHeightKey.self) { footerHeight = $0 }
            .navigationTitle("")
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
                    // Only once the reader has scrolled up: at first layout the
                    // content can be short and this would pull an older page
                    // and jump the thread backwards.
                    if model.cursor != nil, scrolledUp {
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
                        MessageView(message: message, partialCopy: $partialCopy)
                            .equatable()
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
                    Color.clear.frame(height: footerHeight + 44)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .modifier(ScrollUpTracker(scrolledUp: $scrolledUp))
            #if DEBUG
            .onAppear {
                // UI check: start scrolled away from the bottom.
                guard ProcessInfo.processInfo.environment["PUMI_SCROLL_TOP"] == "1" else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if let first = model.messages.first?.id {
                        proxy.scrollTo(first, anchor: .top)
                    }
                }
            }
            #endif
            .overlay(alignment: .bottomTrailing) {
                if scrolledUp {
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
            .onChange(of: model.messages.count) { _, _ in
                guard !scrolledUp else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.pendingUserText) { _, text in
                guard text != nil, !scrolledUp else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: model.liveText) { _, _ in
                guard !scrolledUp else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: model.liveReasoning) { _, _ in
                guard !scrolledUp else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: footerHeight) { _, _ in
                guard !scrolledUp else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
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

/// Distinguishes a reader scrolling up from the content growing: only the
/// former stops auto-follow. Back to the bottom clears it.
private struct ScrollUpTracker: ViewModifier {
    @Binding var scrolledUp: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { old, new in
                let distance = new.contentSize.height
                    - (new.contentOffset.y + new.containerSize.height)
                if new.contentOffset.y < old.contentOffset.y - 1, distance > 120 {
                    scrolledUp = true
                }
                if distance <= 120 {
                    scrolledUp = false
                }
            }
        } else {
            content
        }
    }
}

private struct FooterHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
