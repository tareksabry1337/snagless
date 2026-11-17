import SnaglessModel

struct DiagnosticReport {
    private struct Site: Hashable {
        let path: String
        let location: SourceLocation
        let need: TypeName
    }

    private struct Witness: CustomStringConvertible {
        let requiringView: NodeName
        let path: [String]
        let source: RequirementSource

        var description: String {
            path.joined(separator: " → ") + " (\(source.path):\(source.location.line))"
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
        let severity: Severity
    }

    private struct NextStep {
        let step: Step
        let edge: LinkedChild
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
                            shownFrom: "sheet in \(label)",
                            severity: severity,
                        )
                    )
                } else {
                    add(
                        Finding(
                            child: child,
                            rootProvides: root.kind == .app ? delegateTypes : [],
                            shownFrom: label,
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
                        shownFrom: "sheet in `\(index.nodes[node].name)`",
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
            let message = "`\(witness.requiringView)` needs `\(need)`: \(finding.shownFrom) → \(witness)"
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
        var entersDestination: [Step: Bool] = [:]
        for step in steps(into: edge, need: need, arriving: { $0.all.contains(need) }) {
            queue.append(step)
            entersDestination[step] = edge.passesNavigationDestination(from: step.source)
        }
        var parent: [Step: Step] = [:]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            if current.source == .parent, let source = needs.direct[current.node][need] {
                var path: [String] = []
                var step = current
                while true {
                    path.append(index.nodes[step.node].name.description)
                    if entersDestination[step, default: false] {
                        path.append("navigationDestination")
                    }
                    guard let previous = parent[step] else { break }
                    step = previous
                }
                return Witness(
                    requiringView: index.nodes[current.node].name,
                    path: path.reversed(),
                    source: source,
                )
            }
            let next = links.nodes[current.node]
                .filter { !$0.startsEmpty }
                .flatMap { child in
                    steps(into: child, need: need, arriving: { $0.contains(need, from: current.source) })
                        .map { NextStep(step: $0, edge: child) }
                }
                .sorted {
                    (index.nodes[$0.step.node].name, $0.step.node, $0.step.source.rawValue)
                        < (index.nodes[$1.step.node].name, $1.step.node, $1.step.source.rawValue)
                }
            for candidate in next where entersDestination[candidate.step] == nil {
                let step = candidate.step
                parent[step] = current
                entersDestination[step] = candidate.edge.passesNavigationDestination(from: step.source)
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
