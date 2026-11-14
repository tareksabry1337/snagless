import SwiftUI

struct CaseBrowser: View {
    @State
    private var selected: RuntimeCase?

    init(selected: RuntimeCase?) {
        _selected = State(initialValue: selected)
    }

    var body: some View {
        if let selected {
            RuntimeCaseView(runtimeCase: selected)
                .overlay(alignment: .topLeading) {
                    Button("All cases") { self.selected = nil }.padding()
                }
        } else {
            NavigationStack {
                List(RuntimeCase.allCases, id: \.self) { runtimeCase in
                    Button(runtimeCase.rawValue) { selected = runtimeCase }
                }
                .navigationTitle("Runtime cases")
            }
        }
    }
}
