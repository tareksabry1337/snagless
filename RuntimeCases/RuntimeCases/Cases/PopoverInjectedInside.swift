import SwiftUI

enum PopoverInjectedInside {
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
        private var isPresented = true

        var body: some View {
            Text("Host")
                .environment(Model())
                .popover(isPresented: $isPresented) {
                    Reader().presentationCompactAdaptation(.popover)
                }
        }
    }
}
