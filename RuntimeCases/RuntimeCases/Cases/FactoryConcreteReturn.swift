import SwiftUI

enum FactoryConcreteReturn {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    @MainActor
    enum Factory {
        static func reader() -> Reader {
            Reader()
        }
    }

    struct Root: View {
        var body: some View {
            Factory.reader()
        }
    }
}
