package enum RootKind {
    case app
    case preview
    case hosting
    case widget
}

package enum RootOrigin: Hashable {
    case app(TypeName)
    case widget(name: String)
    case hosting(enclosing: String)
    case preview(title: String)

    package var kind: RootKind {
        switch self {
        case .app:
            return .app
        case .widget:
            return .widget
        case .hosting:
            return .hosting
        case .preview:
            return .preview
        }
    }

    package var label: String {
        switch self {
        case .app(let type):
            return "App `\(type)`"
        case .widget(let name):
            return "widget `\(name)`"
        case .hosting(let enclosing):
            return "a hosting controller in `\(enclosing)`"
        case .preview(let title):
            return "preview `\(title)`"
        }
    }
}

package struct RootSummary {
    package let origin: RootOrigin
    package let scope: Int
    package let location: SourceLocation
    package let hostingCandidate: TypeName?
    package var edges: [Edge]

    package init(
        origin: RootOrigin,
        scope: Int,
        location: SourceLocation,
        hostingCandidate: TypeName? = nil,
        edges: [Edge] = [],
    ) {
        self.origin = origin
        self.scope = scope
        self.location = location
        self.hostingCandidate = hostingCandidate
        self.edges = edges
    }
}
