import SwiftUI

enum CustomScene {
    @Observable
    final class Model {}

    struct Cases: Scene {
        var body: some Scene {
            WindowGroup {
                CaseBrowser(selected: LaunchArguments.runtimeCase)
            }
            .environment(Model())
        }
    }

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }
}
