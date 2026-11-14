import SnaglessModel

package enum Severity: String {
    case error
    case warning
}

package struct DiagnosticNote: Hashable {
    package let path: String
    package let location: SourceLocation
    package let message: String

    var rendered: String {
        "\(path):\(location.line):\(location.column): note: \(message)"
    }
}

package struct Diagnostic: Hashable {
    package let path: String
    package let location: SourceLocation
    package let severity: Severity
    package let message: String
    package let subject: String
    package var notes: [DiagnosticNote] = []

    package var rendered: String {
        let headline = "\(path):\(location.line):\(location.column): \(severity.rawValue): \(message)"
        return ([headline] + notes.map(\.rendered)).joined(separator: "\n")
    }
}

package enum PreviewMode: String {
    case error
    case warning
    case off
}

package struct AnalysisOptions {
    package let previews: PreviewMode
    package let legacySheets: Bool

    package init(previews: PreviewMode = .error, legacySheets: Bool = false) {
        self.previews = previews
        self.legacySheets = legacySheets
    }
}

package struct GraphStats {
    package let views: Int
    package let edges: Int
    package let requirements: Int
    package let roots: Int
    package let reachableViews: Int
    package let unresolvedInjections: Int
    package let fixpointPasses: Int
    package let activeSuppressions: Int
}

package struct UnresolvedInjectionSite {
    package let path: String
    package let injection: UnresolvedInjection
}

package struct UnreachableView {
    package let path: String
    package let name: NodeName
}

package struct Analysis {
    package let diagnostics: [Diagnostic]
    package let stats: GraphStats
    package let unresolved: [UnresolvedInjectionSite]
    package let unreachableViews: [UnreachableView]
    package let unreadablePaths: [String]
}

private struct LinkedGraph {
    let files: [SummarizedFile]
    let memberTypes: MemberTypes
    let suppressions: SuppressionIndex
    let index: NodeIndex
    let links: Links
    let needs: Needs

    init(_ written: consuming [SummarizedFile], options: AnalysisOptions) {
        var files = written
        files.sort { $0.file.path < $1.file.path }
        let resolver = TypeResolver(files)
        Workers.replace(&files) { FileReferenceResolver.resolve($0, with: resolver) }
        let types = DeclaredTypes(files)
        memberTypes = MemberTypes(files)
        suppressions = SuppressionIndex(files)
        index = NodeIndex(files, types: types, suppressions: suppressions)
        var linker = EdgeLinker(
            files: files,
            index: index,
            types: types,
            memberTypes: memberTypes,
            options: options,
            suppressions: suppressions,
        )
        links = linker.linkAll()
        needs = Needs(index: index, links: links)
        self.files = files
    }

    var unresolved: [UnresolvedInjectionSite] {
        files.flatMap { file in
            file.summary.unresolved
                .filter { injection in injection.pending.flatMap(memberTypes.type(of:)) == nil }
                .map { UnresolvedInjectionSite(path: file.file.path, injection: $0) }
        }
    }
}

extension Analysis {
    package init(_ written: consuming [SummarizedFile], options: AnalysisOptions) {
        let graph = LinkedGraph(written, options: options)
        let index = graph.index
        let reachable = Reachability(links: graph.links)
        let unresolved = graph.unresolved
        var report = DiagnosticReport(
            files: graph.files,
            index: index,
            links: graph.links,
            needs: graph.needs,
            options: options,
            delegateTypes: Set(graph.files.flatMap { $0.summary.delegateTypes.map(\.type) }),
        )
        report.addRootFindings()
        if options.legacySheets {
            report.addLegacySheetFindings(reachable: reachable.nodes)
        }
        let keys = TrappingKeys(graph.files, suppressions: graph.suppressions)
        let audit = SuppressionAudit(
            graph.files,
            suppressions: graph.suppressions,
            used: index.usedSuppressions.union(keys.usedSuppressions),
            links: graph.links,
            needs: graph.needs,
        )
        let views = index.nodes.indices.filter { index.nodes[$0].isView }
        self.init(
            diagnostics: report.diagnostics + keys.diagnostics + audit.diagnostics,
            stats: GraphStats(
                views: views.count,
                edges: graph.links.nodes.joined().count + graph.links.roots.joined().count,
                requirements: index.nodes.reduce(0) { $0 + $1.requirements.count },
                roots: index.roots.count,
                reachableViews: views.filter(reachable.nodes.contains).count,
                unresolvedInjections: unresolved.count,
                fixpointPasses: graph.needs.passes,
                activeSuppressions: audit.active,
            ),
            unresolved: unresolved,
            unreachableViews: views.filter { !reachable.nodes.contains($0) }
                .map {
                    UnreachableView(path: index.nodes[$0].path, name: index.nodes[$0].name)
                },
            unreadablePaths: graph.files.filter(\.summary.hasSyntaxErrors).map(\.file.path),
        )
    }
}
