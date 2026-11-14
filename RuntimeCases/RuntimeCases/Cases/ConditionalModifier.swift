import SwiftUI

enum ConditionalModifier {
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
        let flag: Bool

        var body: some View {
            Reader().if(flag) { $0.environment(Model()) }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content>(_ condition: Bool, _ transform: (Self) -> Content) -> some View where Content: SwiftUI.View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
