import SwiftUI

@main
struct RuntimeCasesApp: App {
    init() {
        if LaunchArguments.listsCases {
            print(RuntimeCase.allCases.map(\.rawValue).joined(separator: "\n"))
            exit(0)
        }
    }

    var body: some Scene {
        CustomScene.Cases()
            .environment(SceneEnvironment.Model())
    }
}
