import SwiftUI

@main
struct TabWatchApp: App {
    @StateObject private var store = TabStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
