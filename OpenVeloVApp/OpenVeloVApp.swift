import SwiftUI

@main
struct OpenVeloVApp: App {
    init() {
        BackgroundRefreshManager.register()
        PhoneWatchConnectivity.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
