import SwiftUI

enum EntryWrittenNotRead {
    struct Value {
        let label: String
    }

    struct Reader: View {
        var body: some View {
            Text("Reads nothing").reportsRendered()
        }
    }

    struct Root: View {
        var body: some View {
            Reader().environment(\.entryWrittenNotRead, Value(label: "entry"))
        }
    }
}

extension EnvironmentValues {
    @Entry
    var entryWrittenNotRead: EntryWrittenNotRead.Value = { fatalError("EntryWrittenNotRead default was read") }()
}
