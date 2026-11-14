import SwiftUI

enum SplitViewInjectedOnSplitView {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    struct Root: View {
        @State
        private var column = NavigationSplitViewColumn.detail

        var body: some View {
            NavigationSplitView(preferredCompactColumn: $column) {
                Text("Sidebar")
            } detail: {
                Reader()
            }
            .environment(Model())
        }
    }
}
