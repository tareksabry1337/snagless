import SwiftUI

enum KeyInjected {
    struct Value {
        let label: String
    }

    struct Key: EnvironmentKey {
        static var defaultValue: Value {
            fatalError("KeyInjected.Key was read before anything set it")
        }
    }

    struct Reader: View {
        @Environment(\.injectedValue)
        private var value

        var body: some View {
            Text(value.label).reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environment(\.injectedValue, Value(label: "key"))
        }
    }
}

extension EnvironmentValues {
    var injectedValue: KeyInjected.Value {
        get { self[KeyInjected.Key.self] }
        set { self[KeyInjected.Key.self] = newValue }
    }
}
