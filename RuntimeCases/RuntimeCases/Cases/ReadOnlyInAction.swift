import SwiftUI

enum ReadOnlyInAction {
    @Observable
    final class Model {
        func refresh() {}
    }

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Button("Refresh") { model.refresh() }.reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
