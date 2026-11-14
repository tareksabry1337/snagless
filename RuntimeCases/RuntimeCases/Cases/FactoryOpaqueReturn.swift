import SwiftUI

enum FactoryOpaqueReturn {
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
        static func reader() -> some View {
            Reader()
        }
    }

    struct Root: View {
        var body: some View {
            Factory.reader()
        }
    }
}
