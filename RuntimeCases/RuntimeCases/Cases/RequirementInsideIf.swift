import SwiftUI

enum RequirementInsideIf {
    @Observable
    final class Model {}

    struct Reader: View {
        #if os(iOS)
        @Environment(Model.self)
        private var model
        #endif

        var body: some View {
            #if os(iOS)
            Text(verbatim: "\(model)").reportsRendered()
            #else
            Text("Not iOS").reportsRendered()
            #endif
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
