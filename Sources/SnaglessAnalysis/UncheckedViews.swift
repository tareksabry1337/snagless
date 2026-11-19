import SnaglessModel

struct UncheckedViews {
    let diagnostics: [Diagnostic]
    let count: Int
    let unreachableCount: Int
    let listed: [UnreachableView]

    init(views: [Int], index: NodeIndex, links: Links, previews: PreviewMode) {
        let checkedRoots = index.roots.indices.filter { previews != .off || index.roots[$0].kind != .preview }
        let reached = Reachability(links: links, from: checkedRoots).nodes
        let unreachable = views.filter { !reached.contains($0) }.map { index.nodes[$0] }
        unreachableCount = unreachable.count
        let hasAppRoot = index.roots.contains { $0.kind != .preview }
        let message = Self.unreachableMessage(previews: previews)
        let warnings = unreachable.compactMap { view in
            view.requirements.first.map { first in
                Diagnostic(
                    path: first.source.path,
                    location: first.source.location,
                    severity: .warning,
                    message: message(view.name),
                    subject: view.name.description,
                )
            }
        }
        count = warnings.count
        let anchor = warnings.min { ($0.path, $0.location) < ($1.path, $1.location) }
        guard !hasAppRoot, let anchor else {
            diagnostics = warnings
            listed = unreachable.filter(\.requirements.isEmpty).map { Self.listed($0, message: message) }
            return
        }
        diagnostics = [
            Diagnostic(
                path: anchor.path,
                location: anchor.location,
                severity: .warning,
                message: Self.oneWarning(naming: anchor.subject, others: count - 1),
                subject: "",
            )
        ]
        listed = unreachable.map { Self.listed($0, message: message) }
    }

    private static func oneWarning(naming view: String, others: Int) -> String {
        switch others {
        case 0:
            "`\(view)` reads the environment and is unchecked; run Snagless on the app that shows it"
        case 1:
            "`\(view)` and 1 other view that read the environment are unchecked; run Snagless on the app that shows them"
        default:
            "`\(view)` and \(others) other views that read the environment are unchecked; "
                + "run Snagless on the app that shows them"
        }
    }

    private static func unreachableMessage(previews: PreviewMode) -> (NodeName) -> String {
        let roots = previews == .off ? "every App and hosting root" : "every App, preview and hosting root"
        return { "`\($0)` is unreachable from \(roots)" }
    }

    private static func listed(_ view: GraphNode, message: (NodeName) -> String) -> UnreachableView {
        UnreachableView(path: view.path, name: view.name, message: message(view.name))
    }
}
