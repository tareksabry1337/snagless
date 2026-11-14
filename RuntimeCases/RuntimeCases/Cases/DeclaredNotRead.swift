import SwiftUI

enum DeclaredNotRead {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text("Declares Model, never reads it").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
