import SwiftUI

@main
struct PumiApp: App {
    @State private var settings = Settings()

    var body: some Scene {
        WindowGroup {
            SessionListView()
                .environment(settings)
                .preferredColorScheme(.dark)
        }
    }
}
