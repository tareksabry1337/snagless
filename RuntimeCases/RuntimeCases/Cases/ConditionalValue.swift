import SwiftUI

enum ConditionalValue {
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
        let prefersFirst: Bool
        private let first = Model()
        private let second = Model()

        var body: some View {
            Reader().environment(prefersFirst ? first : second)
        }
    }
}
