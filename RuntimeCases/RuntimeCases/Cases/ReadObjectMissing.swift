import SwiftUI

enum ReadObjectMissing {
    final class Store: ObservableObject {}

    struct Reader: View {
        @EnvironmentObject
        private var store: Store

        var body: some View {
            Text(verbatim: "\(store)").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
