import SwiftUI

enum TransformEnvironmentOnly {
    struct Value {
        let label: String
    }

    struct Key: EnvironmentKey {
        static var defaultValue: Value {
            fatalError("TransformEnvironmentOnly.Key was read before anything set it")
        }
    }

    struct Reader: View {
        @Environment(\.transformOnlyValue)
        private var value

        var body: some View {
            Text(value.label).reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader()
                .transformEnvironment(\.transformOnlyValue) { value in
                    value = Value(label: "transformed")
                }
        }
    }
}

extension EnvironmentValues {
    var transformOnlyValue: TransformEnvironmentOnly.Value {
        get { self[TransformEnvironmentOnly.Key.self] }
        set { self[TransformEnvironmentOnly.Key.self] = newValue }
    }
}
