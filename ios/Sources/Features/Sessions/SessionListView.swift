import SwiftUI

struct SessionListView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = SessionListModel()
    @State private var showSettings = false
    @State private var path: [OcSession] = []
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "プロジェクトを検索"
                )
                .navigationDestination(for: OcSession.self) { session in
                    if let client = settings.client {
                        ChatView(session: session, client: client)
                    }
                }
                .task(id: settings.baseURLText) {
                    await model.load(client: settings.client)
                    #if DEBUG
                    // UI screenshots in the simulator: PUMI_SESSION=<id>
                    // env var opens that session on launch.
                    if let id = ProcessInfo.processInfo.environment["PUMI_SESSION"] {
                        await openSession(id: id)
                    }
                    #endif
                }
                .refreshable {
                    await model.load(client: settings.client)
                }
        }
        .onOpenURL { url in
            Task { await open(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.load(client: settings.client) }
        }
    }

    /// `pumi://sessions/<id>` from a notification. A session that is not on the
    /// loaded page is fetched by id before pushing.
    private func open(_ url: URL) async {
        guard url.scheme == "pumi", url.host == "sessions",
              let id = url.pathComponents.dropFirst().first else { return }
        await openSession(id: id)
    }

    private func openSession(id: String) async {
        guard let client = settings.client else { return }
        if let session = model.sessions.first(where: { $0.id == id }) {
            path = [session]
        } else if let session = try? await client.session(id) {
            path = [session]
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.sessions.isEmpty {
            if model.loading {
                ProgressView()
            } else if let error = model.error {
                ContentUnavailableView {
                    Label("読み込めません", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("\(settings.baseURLText)\n\n\(error)")
                        .textSelection(.enabled)
                } actions: {
                    Button("再試行") {
                        Task { await model.load(client: settings.client) }
                    }
                }
            } else {
                ContentUnavailableView(
                    "セッションなし",
                    systemImage: "tray",
                    description: Text("opencode でセッションを作るとここに出ます")
                )
            }
        } else if filteredGroups.isEmpty, !query.isEmpty {
            ContentUnavailableView {
                Label("見つかりません", systemImage: "magnifyingglass")
            } description: {
                Text("読み込み済みの範囲に「\(query)」はありません")
            } actions: {
                if model.hasMore {
                    Button("さらに読み込む") {
                        Task { await model.loadMore(client: settings.client) }
                    }
                }
            }
        } else {
            List {
                ForEach(filteredGroups) { group in
                    Section(group.name) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session)
                            }
                        }
                    }
                }
                if model.hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .onAppear {
                        Task { await model.loadMore(client: settings.client) }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var filteredGroups: [SessionListModel.Group] {
        model.groups(matching: query)
    }
}

struct SessionRow: View {
    let session: OcSession

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusDot(session: session)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title?.isEmpty == false ? session.title! : session.id)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let agent = session.agent { Text(agent) }
                    if let directory = session.location?.directory {
                        Text(URL(fileURLWithPath: directory).lastPathComponent)
                    }
                    Text(Format.relative(session.time?.updated ?? session.time?.created))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct StatusDot: View {
    let session: OcSession

    var body: some View {
        Group {
            if session.pending != nil {
                Circle().fill(.orange)
            } else if session.active == true {
                Circle().fill(.blue)
            } else if Format.isUnread(session) {
                Circle().fill(.green)
            } else {
                Circle().fill(.clear)
            }
        }
        .frame(width: 8, height: 8)
        .padding(.top, 5)
    }
}
