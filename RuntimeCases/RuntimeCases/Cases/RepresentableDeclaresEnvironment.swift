import SwiftUI
import UIKit

enum RepresentableDeclaresEnvironment {
    @Observable
    final class Model {}

    struct Label: UIViewRepresentable {
        @Environment(Model.self)
        private var model

        func makeUIView(context: Context) -> UILabel {
            UILabel()
        }

        func updateUIView(_ label: UILabel, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            Label().reportsRendered()
        }
    }
}
