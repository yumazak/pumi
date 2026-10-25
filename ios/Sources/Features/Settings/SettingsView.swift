import SwiftUI

struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            Form {
                Section("サーバ") {
                    TextField("http://127.0.0.1:7180", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    Toggle("ストリーミング表示", isOn: $settings.streaming)
                } footer: {
                    Text("オフにすると、応答は完了時にまとめて表示されます（SSE は動き続けます）。")
                }
                Section {
                    Text("実機は Tailscale の HTTPS URL を入れる（例: https://<machine>.<tailnet>.ts.net:8443）。シミュレータは http://127.0.0.1:7180 のまま。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        settings.baseURLText = text
                        dismiss()
                    }
                }
            }
            .onAppear { text = settings.baseURLText }
        }
    }
}
