import SwiftUI

enum PreviewForms {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)")
        }
    }
}

#Preview("Traits, missing", traits: .sizeThatFitsLayout) {
    PreviewForms.Reader()
}

#Preview("Previewable, injected") {
    @Previewable
    @State
    var model = PreviewForms.Model()
    PreviewForms.Reader().environment(model)
}

#if DEBUG
#Preview("Inside if DEBUG, missing") {
    PreviewForms.Reader()
}
#endif
