import SwiftUI

enum SplitViewDestinationInjectedBetween {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    struct Declarer: View {
        @State
        private var isPresented = true

        var body: some View {
            Text("Declarer").navigationDestination(isPresented: $isPresented) { Reader() }
        }
    }

    struct Root: View {
        @State
        private var column = NavigationSplitViewColumn.sidebar

        var body: some View {
            NavigationSplitView(preferredCompactColumn: $column) {
                Declarer().environment(Model())
            } detail: {
                Text("Detail")
            }
        }
    }
}
