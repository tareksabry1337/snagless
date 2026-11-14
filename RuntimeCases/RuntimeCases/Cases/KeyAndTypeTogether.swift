import SwiftUI

enum KeyAndTypeTogether {
    @Observable
    final class Model {}

    struct Value {
        let label: String
    }

    struct Key: EnvironmentKey {
        static var defaultValue: Value {
            fatalError("KeyAndTypeTogether.Key was read before anything set it")
        }
    }

    struct Reader: View {
        @Environment(\.keyAndTypeValue)
        private var value
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(value.label) \(model)").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
                .environment(\.keyAndTypeValue, Value(label: "key"))
                .environment(Model())
        }
    }
}

extension EnvironmentValues {
    var keyAndTypeValue: KeyAndTypeTogether.Value {
        get { self[KeyAndTypeTogether.Key.self] }
        set { self[KeyAndTypeTogether.Key.self] = newValue }
    }
}
