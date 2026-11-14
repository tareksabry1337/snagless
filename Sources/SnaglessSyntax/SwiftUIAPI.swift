import SnaglessModel

enum SwiftUIAPI {
    static let injectionModifiers: Set<String> = ["environment", "environmentObject"]
    static let keyWriters: Set<String> = ["environment", "transformEnvironment"]
    static let boundaryModifiers: [String: Boundary.Kind] = [
        "sheet": .presentation,
        "popover": .presentation,
        "fullScreenCover": .presentation,
        "navigationDestination": .navigationDestination,
    ]
    static let navigationStack = "NavigationStack"
    static let controllerRepresentables: Set<String> = [
        "UIViewControllerRepresentable", "NSViewControllerRepresentable",
    ]
    static let controllerMakers: Set<String> = ["makeUIViewController", "makeNSViewController"]
    static let viewConformances = controllerRepresentables.union([
        "View", "ViewModifier", "ToolbarContent", "Commands", "UIViewRepresentable", "NSViewRepresentable",
    ])
    static let customModifier = "modifier"
}
