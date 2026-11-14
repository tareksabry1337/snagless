import SwiftUI
import UIKit

enum HostingControllerChild {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    struct Hosted: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIHostingController<Reader> {
            UIHostingController(rootView: Reader())
        }

        func updateUIViewController(_ controller: UIHostingController<Reader>, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            Hosted().environment(Model())
        }
    }
}
