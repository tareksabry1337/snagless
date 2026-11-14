import SwiftUI

enum DeclaredNotReadObject {
    final class Store: ObservableObject {}

    struct Reader: View {
        @EnvironmentObject
        private var store: Store

        var body: some View {
            Text("Declares Store, never reads it").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
        }
    }
}
