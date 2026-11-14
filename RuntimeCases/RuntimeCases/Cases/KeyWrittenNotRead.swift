import SwiftUI

enum KeyWrittenNotRead {
    struct Value {
        let label: String
    }

    struct Key: EnvironmentKey {
        static var defaultValue: Value {
            fatalError("KeyWrittenNotRead.Key default was read")
        }
    }

    struct Reader: View {
        var body: some View {
            Text("Reads nothing").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environment(\.writtenNotReadValue, Value(label: "key"))
        }
    }
}

extension EnvironmentValues {
    var writtenNotReadValue: KeyWrittenNotRead.Value {
        get { self[KeyWrittenNotRead.Key.self] }
        set { self[KeyWrittenNotRead.Key.self] = newValue }
    }
}
