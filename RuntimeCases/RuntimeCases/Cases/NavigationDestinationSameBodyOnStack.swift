import SwiftUI

enum NavigationDestinationSameBodyOnStack {
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
        private var path = [1]

        var body: some View {
            NavigationStack(path: $path) {
                Text("Declarer").navigationDestination(for: Int.self) { _ in Reader() }
            }
            .environment(Model())
        }
    }
}
