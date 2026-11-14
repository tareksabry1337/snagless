import SwiftUI

enum ConditionalBranch {
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
        let injects: Bool

        var body: some View {
            if injects {
                Reader().environment(Model())
            } else {
                Reader()
            }
        }
    }
}
