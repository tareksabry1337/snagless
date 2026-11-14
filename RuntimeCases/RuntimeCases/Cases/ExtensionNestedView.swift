import SwiftUI

enum ExtensionNestedView {
    @Observable
    final class Model {}

    struct Root: View {
        var body: some View {
            Row()
        }
    }
}

extension ExtensionNestedView {
    struct Row: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }
}
