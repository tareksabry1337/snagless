import SwiftUI

enum PostfixIfOtherPlatform {
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
            Reader()
                .padding()
                #if os(macOS)
            .environment(Model())
                #endif
        }
    }
}
