import SnaglessModel

struct DiagnosticReport {
    private struct Site: Hashable {
        let path: String
        let location: SourceLocation
        let need: TypeName
    }

    private struct Witness: CustomStringConvertible {
        let path: [NodeName]
        let source: RequirementSource
        let passesNavigationDestination: Bool

        var description: String {
            path.map(\.description).joined(separator: " → ") + " (\(source.path):\(source.location.line))"
        }
    }

    private struct Step: Hashable {
        let node: Int
        let source: NeedSet.Source
    }

    private struct Finding {
        let child: LinkedChild
        let rootProvides: Set<TypeName>
        let shownFrom: String
        let kind: RootKind
        let severity: Severity
    }

    private let files: [SummarizedFile]
    private let index: NodeIndex
    private let links: Links
    private let needs: Needs
    private let options: AnalysisOptions
    private let delegateTypes: Set<TypeName>
    private var reported: Set<Site> = []
    private(set) var diagnostics: [Diagnostic] = []

    init(
        files: [SummarizedFile],
        index: NodeIndex,
        links: Links,
        needs: Needs,
        options: AnalysisOptions,
        delegateTypes: Set<TypeName>,
    ) {
        self.files = files
        self.index = index
        self.links = links
        self.needs = needs
        self.options = options
        self.delegateTypes = delegateTypes
    }

    mutating func addRootFindings() {
        for (root, children) in zip(index.roots, links.roots) {
            if root.kind == .preview && options.previews == .off {
                continue
            }
            let severity: Severity = root.kind == .preview && options.previews == .warning ? .warning : .error
            let label = root.summary.origin.label
            for child in children {
                if child.startsEmpty {
                    add(
                        Finding(
                            child: child,
                            rootProvides: [],
                            shownFrom: "a sheet in \(label)",
                            kind: .presentation,
                            severity: severity,
                        )
                    )
                } else {
                    add(
                        Finding(
                            child: child,
                            rootProvides: root.kind == .app ? delegateTypes : [],
                            shownFrom: label,
                            kind: root.kind,
                            severity: severity,
                        )
                    )
                }
            }
        }
    }

    mutating func addLegacySheetFindings(reachable: Set<Int>) {
        for node in index.nodes.indices where reachable.contains(node) {
            for child in links.nodes[node] where child.startsEmpty {
                add(
                    Finding(
                        child: child,
                        rootProvides: [],
                        shownFrom: "a sheet in `\(index.nodes[node].name)`",
                        kind: .presentation,
                        severity: .error,
                    )
                )
            }
        }
    }

    private mutating func add(_ finding: Finding) {
        let edge = finding.child
        let path = files[edge.file].file.path
        let location = edge.location
        for need in edge.carry(needs.all[edge.node]).all.sorted() where !finding.rootProvides.contains(need) {
            guard reported.insert(Site(path: path, location: location, need: need)).inserted,
                let witness = witness(through: edge, need: need)
            else { continue }
            var message =
                "`\(index.nodes[edge.node].name)` is shown from \(finding.shownFrom)"
                + " without `\(need)`; required by \(witness)."
            if finding.kind == .presentation {
                message +=
                    " With --legacy-sheets, a sheet starts with an empty environment."
            }
            if witness.passesNavigationDestination {
                message +=
                    " A navigationDestination gets the environment of its NavigationStack;"
                    + " provide the value on the stack or inside the destination."
            }
            diagnostics.append(
                Diagnostic(
                    path: path,
                    location: location,
                    severity: finding.severity,
                    message: message,
                    subject: need.description,
                )
            )
        }
    }

    private func witness(through edge: LinkedChild, need: TypeName) -> Witness? {
        var queue: [Step] = []
        var passesDestination: [Step: Bool] = [:]
        for step in steps(into: edge, need: need, arriving: { $0.all.contains(need) }) {
            queue.append(step)
            passesDestination[step] = edge.passesNavigationDestination(from: step.source)
        }
        var parent: [Step: Step] = [:]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            if current.source == .parent, let source = needs.direct[current.node][need] {
                var path = [index.nodes[current.node].name]
                var step = current
                while let previous = parent[step] {
                    path.append(index.nodes[previous.node].name)
                    step = previous
                }
                return Witness(
                    path: path.reversed(),
                    source: source,
                    passesNavigationDestination: passesDestination[current, default: false],
                )
            }
            let next = links.nodes[current.node]
                .filter { !$0.startsEmpty }
                .flatMap { child in
                    steps(into: child, need: need, arriving: { $0.contains(need, from: current.source) })
                        .map { (step: $0, edge: child) }
                }
                .sorted {
                    (index.nodes[$0.step.node].name, $0.step.node, $0.step.source.rawValue)
                        < (index.nodes[$1.step.node].name, $1.step.node, $1.step.source.rawValue)
                }
            for (step, child) in next where passesDestination[step] == nil {
                parent[step] = current
                passesDestination[step] =
                    passesDestination[current, default: false] || child.passesNavigationDestination(from: step.source)
                queue.append(step)
            }
        }
        return nil
    }

    private func steps(into edge: LinkedChild, need: TypeName, arriving: (NeedSet) -> Bool) -> [Step] {
        NeedSet.Source.allCases
            .filter { needs.all[edge.node].contains(need, from: $0) && arriving(edge.carry(NeedSet(need, from: $0))) }
            .map { Step(node: edge.node, source: $0) }
    }
}
