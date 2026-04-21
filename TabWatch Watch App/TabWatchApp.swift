import SwiftUI

@main
struct TabWatchApp: App {
    @StateObject private var store = TabStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, newPhase in
                    // Re-check the business-day boundary whenever the app
                    // comes forward. Without this, "Today" stays stale
                    // across midnight until the next close-out triggers it.
                    if newPhase == .active {
                        store.rollOverIfNeeded()
                    }
                }
        }
    }
}
