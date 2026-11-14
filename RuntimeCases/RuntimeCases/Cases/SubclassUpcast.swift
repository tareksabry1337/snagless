import SwiftUI

enum SubclassUpcast {
    @Observable
    class Model {}

    final class Subclass: Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environment(Subclass() as Model)
        }
    }
}
