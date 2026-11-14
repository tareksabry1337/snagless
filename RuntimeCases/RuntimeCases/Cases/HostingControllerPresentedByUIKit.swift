import SwiftUI
import UIKit

enum HostingControllerPresentedByUIKit {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    final class Presenter: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            present(UIHostingController(rootView: Reader()), animated: false)
        }
    }

    struct Hosted: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> Presenter {
            Presenter()
        }

        func updateUIViewController(_ controller: Presenter, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            Hosted().environment(Model())
        }
    }
}
