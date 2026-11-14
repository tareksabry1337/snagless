import SwiftUI

struct ReportsRendered: ViewModifier {
    static let marker = "runtime-case: rendered"

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                Label("Rendered", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .onAppear {
                print(Self.marker)
                if LaunchArguments.runtimeCase != nil {
                    exit(0)
                }
            }
    }
}

extension View {
    func reportsRendered() -> some View {
        modifier(ReportsRendered())
    }
}
