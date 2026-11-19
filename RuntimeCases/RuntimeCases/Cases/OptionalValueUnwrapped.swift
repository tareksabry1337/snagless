import SwiftUI

enum OptionalValueUnwrapped {
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
        private var model: Model?

        var body: some View {
            ZStack {
                Text("Root")
                if let model {
                    Reader().environment(model)
                }
            }
            .task { model = Model() }
        }
    }
}
