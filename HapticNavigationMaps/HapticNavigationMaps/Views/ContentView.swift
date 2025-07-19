import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            MapView()
                .navigationTitle("Haptic Navigation")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}