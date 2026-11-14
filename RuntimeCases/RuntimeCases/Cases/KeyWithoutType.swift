import SwiftUI

enum KeyWithoutType {
    @Observable
    final class Model {}

    struct Value {
        let label: String
    }

    struct Key: EnvironmentKey {
        static var defaultValue: Value {
            fatalError("KeyWithoutType.Key was read before anything set it")
        }
    }

    struct Reader: View {
        @Environment(\.keyWithoutTypeValue)
        private var value
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(value.label) \(model)").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environment(\.keyWithoutTypeValue, Value(label: "key"))
        }
    }
}

extension EnvironmentValues {
    var keyWithoutTypeValue: KeyWithoutType.Value {
        get { self[KeyWithoutType.Key.self] }
        set { self[KeyWithoutType.Key.self] = newValue }
    }
}
