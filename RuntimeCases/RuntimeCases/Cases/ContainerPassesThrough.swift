import SwiftUI

enum ContainerPassesThrough {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    struct Container<Content: View>: View {
        @ViewBuilder
        let content: Content

        var body: some View {
            VStack { content }
        }
    }

    struct Root: View {
        var body: some View {
            Container { Reader() }
        }
    }
}
