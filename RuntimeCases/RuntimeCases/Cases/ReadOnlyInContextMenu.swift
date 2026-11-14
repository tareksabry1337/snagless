import SwiftUI

enum ReadOnlyInContextMenu {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text("Long-press for the menu")
                .contextMenu {
                    Text(verbatim: "\(model)")
                } preview: {
                    Text(verbatim: "\(model)")
                }
                .reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
