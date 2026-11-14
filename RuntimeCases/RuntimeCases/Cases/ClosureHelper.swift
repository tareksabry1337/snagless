import SwiftUI

enum ClosureHelper {
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
        var body: some View {
            Reader().apply { $0.environment(Model()) }
        }
    }
}

extension View {
    func apply<Content>(_ transform: (Self) -> Content) -> Content where Content: SwiftUI.View {
        transform(self)
    }
}
