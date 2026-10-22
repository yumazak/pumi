import SwiftUI

struct SessionListView: View {
    @Environment(Settings.self) private var settings
    @State private var model = SessionListModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("pumi")
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
                .task(id: settings.baseURLText) {
                    await model.load(client: settings.client)
                }
                .refreshable {
                    await model.load(client: settings.client)
                }
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
                    Text(error)
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
        } else {
            List {
                ForEach(model.groups) { group in
                    Section(group.name) {
                        ForEach(group.sessions) { session in
                            NavigationLink {
                                if let client = settings.client {
                                    ChatView(session: session, client: client)
                                }
                            } label: {
                                SessionRow(session: session)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
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
