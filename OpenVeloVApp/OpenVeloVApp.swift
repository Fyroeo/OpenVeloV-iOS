import SwiftUI

@main
struct OpenVeloVApp: App {
    init() {
        BackgroundRefreshManager.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
