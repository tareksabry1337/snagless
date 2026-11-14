import ProfileKit
import Shop
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            ProfileBadge()
            CartBadge()
        }
    }
}

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Session())
        }
    }
}
