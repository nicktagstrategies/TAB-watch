import SwiftUI

struct ContentView: View {
    var body: some View {
        TabListView()
    }
}

#Preview {
    ContentView()
        .environmentObject(TabStore())
}
