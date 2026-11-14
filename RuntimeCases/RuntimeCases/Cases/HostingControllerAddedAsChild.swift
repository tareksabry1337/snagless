import SwiftUI
import UIKit

enum HostingControllerAddedAsChild {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    final class Container: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            let hosting = UIHostingController(rootView: Reader())
            addChild(hosting)
            hosting.view.frame = view.bounds
            view.addSubview(hosting.view)
            hosting.didMove(toParent: self)
        }
    }

    struct Hosted: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> Container {
            Container()
        }

        func updateUIViewController(_ controller: Container, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            Hosted().environment(Model())
        }
    }
}
