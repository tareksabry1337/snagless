import SwiftUI

enum SubclassEnvironmentObject {
    class Store: ObservableObject {}

    final class Subclass: Store {}

    struct Reader: View {
        @EnvironmentObject
        private var store: Store

        var body: some View {
            Text(verbatim: "\(store)").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environmentObject(Subclass())
        }
    }
}
