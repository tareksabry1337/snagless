import Profile
import SwiftUI

public struct DemoApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Session())
        }
    }
}
