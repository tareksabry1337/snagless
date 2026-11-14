import SwiftUI
import UIKit

enum HostedViewUntakenBranch {
    @Observable
    final class Model {}

    struct EmbeddedRow: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)")
        }
    }

    struct Editor: View {
        let replyTo: String?

        var body: some View {
            VStack {
                Text("Editor").reportsRendered()
                if replyTo != nil {
                    EmbeddedRow()
                }
            }
        }
    }

    struct Hosted: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIHostingController<Editor> {
            UIHostingController(rootView: Editor(replyTo: nil))
        }

        func updateUIViewController(_ controller: UIHostingController<Editor>, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            Hosted()
        }
    }
}
