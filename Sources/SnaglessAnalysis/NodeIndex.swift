import SnaglessModel

struct RequirementSource {
    let path: String
    let location: SourceLocation
}

struct SourcedRequirement {
    let type: TypeName
    let source: RequirementSource
}

struct FileEdges {
    let edges: [Edge]
    let file: Int
}

struct FileRoot {
    let summary: RootSummary
    let file: Int

    var kind: RootKind { summary.origin.kind }
}

struct GraphNode {
    let name: NodeName
    var isViewModifier: Bool
    let module: String
    let path: String
    var requirements: [SourcedRequirement] = []
    var edges: [FileEdges] = []
    var provisions: Set<Provision> = []
    var slots: [[Provision]] = []

    var isView: Bool {
        guard case .type = name else { return false }
        return true
    }
}

struct NodeIndex {
    private struct ModuleNode: Hashable {
        let module: String
        let name: NodeName
    }

    private struct MemberBase: Hashable {
        let owner: TypeName
        let base: String
    }

    let nodes: [GraphNode]
    let roots: [FileRoot]
    let memberBaseNames: Set<String>
    let usedSuppressions: Set<SuppressionID>
    private let byName: [NodeName: [Int]]
    private let labelledMembers: [MemberBase: [Int]]

    init(_ files: [SummarizedFile], types: DeclaredTypes, suppressions: SuppressionIndex) {
        let appTypes = Set(files.flatMap { $0.summary.roots.compactMap(\.appType) })
        var usedSuppressions: Set<SuppressionID> = []
        let nodes = Self.nodes(
            in: files,
            types: types,
            appTypes: appTypes,
            suppressions: suppressions,
            usedSuppressions: &usedSuppressions,
        )
        self.usedSuppressions = usedSuppressions
        var byName: [NodeName: [Int]] = [:]
        var memberBaseNames: Set<String> = []
        var labelledMembers: [MemberBase: [Int]] = [:]
        for (index, node) in nodes.enumerated() {
            byName[node.name, default: []].append(index)
            guard case .member(let owner, let member) = node.name else { continue }
            memberBaseNames.insert(member.base)
            if case .called = member.labels {
                labelledMembers[MemberBase(owner: owner, base: member.base), default: []].append(index)
            }
        }
        self.nodes = nodes
        self.roots = Self.roots(in: files, types: types, appTypes: appTypes)
        self.byName = byName
        self.memberBaseNames = memberBaseNames
        self.labelledMembers = labelledMembers
    }

    private static func roots(in files: [SummarizedFile], types: DeclaredTypes, appTypes: Set<TypeName>) -> [FileRoot] {
        var roots: [FileRoot] = []
        for (file, summarized) in files.enumerated() {
            for root in summarized.summary.roots {
                if let candidate = root.hostingCandidate, !types.isHosting(candidate) {
                    continue
                }
                roots.append(FileRoot(summary: root, file: file))
            }
            for node in summarized.summary.nodes {
                guard let owner = node.name.owner, appTypes.contains(owner) else { continue }
                let scene = RootSummary(
                    origin: .app(owner),
                    scope: node.scope,
                    location: node.location,
                    edges: node.edges,
                )
                roots.append(FileRoot(summary: scene, file: file))
            }
        }
        return roots
    }

    private static func nodes(
        in files: [SummarizedFile],
        types: DeclaredTypes,
        appTypes: Set<TypeName>,
        suppressions: SuppressionIndex,
        usedSuppressions: inout Set<SuppressionID>,
    ) -> [GraphNode] {
        var nodes: [GraphNode] = []
        var byModule: [ModuleNode: Int] = [:]
        for (file, summarized) in files.enumerated() {
            for node in summarized.summary.nodes {
                switch node.name {
                case _ where node.name.owner.map(appTypes.contains) == true:
                    continue
                case .type(let type) where !types.isView(type):
                    continue
                case .type, .member, .extensionFunction:
                    break
                }
                let key = ModuleNode(module: summarized.file.module, name: node.name)
                let index = byModule[key] ?? nodes.count
                if index == nodes.count {
                    nodes.append(
                        GraphNode(
                            name: node.name,
                            isViewModifier: node.isViewModifier,
                            module: key.module,
                            path: summarized.file.path,
                        )
                    )
                    byModule[key] = index
                }
                for requirement in node.requirements {
                    if let id = suppressions.ignoring(requirement.type, file: file, line: requirement.location.line) {
                        usedSuppressions.insert(id)
                        continue
                    }
                    nodes[index].requirements
                        .append(
                            SourcedRequirement(
                                type: requirement.type,
                                source: RequirementSource(path: summarized.file.path, location: requirement.location),
                            )
                        )
                }
                nodes[index].edges.append(FileEdges(edges: node.edges, file: file))
                nodes[index].provisions.formUnion(node.provisions)
                nodes[index].slots += node.slots
                nodes[index].isViewModifier = nodes[index].isViewModifier || node.isViewModifier
            }
        }
        return nodes
    }

    func candidates(named name: NodeName) -> [Int] {
        if let exact = byName[name] {
            return exact
        }
        guard case .member(let owner, let member) = name else { return [] }
        return labelledMembers[MemberBase(owner: owner, base: member.base), default: []]
    }
}

extension NodeName {
    var owner: TypeName? {
        switch self {
        case .type(let type), .member(let type, _):
            type
        case .extensionFunction:
            nil
        }
    }
}

extension RootSummary {
    var appType: TypeName? {
        guard case .app(let type) = origin else { return nil }
        return type
    }
}
