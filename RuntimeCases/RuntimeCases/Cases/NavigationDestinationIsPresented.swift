import SwiftUI

enum NavigationDestinationIsPresented {
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
        var body: some View {
            NavigationStack {
                Declarer().environment(Model())
            }
        }
    }
}
