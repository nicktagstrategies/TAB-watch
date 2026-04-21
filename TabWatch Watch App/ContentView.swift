import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TabListView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TabStore())
}
