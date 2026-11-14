import SnaglessModel

struct LinkedChild {
    let node: Int
    let file: Int
    let location: SourceLocation
    let layers: [Layer]
    let startsEmpty: Bool
    let suppressions: [SuppressionID]

    func carry(_ needs: NeedSet) -> NeedSet {
        needs.carried(through: layers)
    }

    func passesNavigationDestination(from source: NeedSet.Source) -> Bool {
        var current = source
        for layer in layers {
            switch layer {
            case .navigationDestination where current == .parent:
                return true
            case .navigationStack:
                current = .parent
            case .provides, .ignores, .navigationDestination:
                continue
            }
        }
        return false
    }
}

struct Links {
    let nodes: [[LinkedChild]]
    let roots: [[LinkedChild]]
}

struct EdgeLinker {
    private struct ModuleType: Hashable {
        let module: String
        let type: TypeName
    }

    private let files: [SummarizedFile]
    private let index: NodeIndex
    private let types: DeclaredTypes
    private let memberTypes: MemberTypes
    private let options: AnalysisOptions
    private let suppressions: SuppressionIndex
    private let providerNeeds: [Provision: Set<TypeName>]
    private var slotNeeds: [ModuleType: Set<TypeName>] = [:]

    init(
        files: [SummarizedFile],
        index: NodeIndex,
        types: DeclaredTypes,
        memberTypes: MemberTypes,
        options: AnalysisOptions,
        suppressions: SuppressionIndex,
    ) {
        self.files = files
        self.index = index
        self.types = types
        self.memberTypes = memberTypes
        self.options = options
        self.suppressions = suppressions
        providerNeeds = Self.providerNeeds(index.nodes, memberTypes: memberTypes)
    }

    mutating func linkAll() -> Links {
        var nodes: [[LinkedChild]] = []
        for node in index.nodes {
            var children: [LinkedChild] = []
            for group in node.edges {
                for edge in group.edges {
                    children += link(edge, file: group.file, isRoot: false)
                }
            }
            nodes.append(children)
        }
        var roots: [[LinkedChild]] = []
        for root in index.roots {
            var children: [LinkedChild] = []
            for edge in root.summary.edges {
                children += link(edge, file: root.file, isRoot: true)
            }
            roots.append(children)
        }
        return Links(nodes: nodes, roots: roots)
    }

    private mutating func link(_ edge: Edge, file: Int, isRoot: Bool) -> [LinkedChild] {
        let found = targets(of: edge, file: file)
        guard !found.isEmpty else { return [] }
        let sheet = options.legacySheets ? edge.boundaries.lastIndex { $0.kind == .presentation } : nil
        let inner = sheet.map { edge.boundaries[($0 + 1)...] } ?? edge.boundaries[...]
        let endsAnalysis = isRoot || sheet != nil
        let ignored = suppressions.ignoredTypes(file: file, line: edge.location.line)
        var layers: [Layer] = ignored.isEmpty ? [] : [.ignores(ignored.compactMap(suppressions.writtenType))]
        var end = edge.provided.count
        for boundary in inner.reversed() {
            layers.append(.provides(needs(providedBy: edge.provided[boundary.start..<end], file: file)))
            if let layer = Self.layer(for: boundary.kind) {
                layers.append(layer)
            }
            end = boundary.start
        }
        if endsAnalysis {
            layers.append(.navigationStack)
        }
        let start = sheet.map { edge.boundaries[$0].start } ?? 0
        layers.append(.provides(needs(providedBy: edge.provided[start..<end], file: file)))
        let children = found.count > 1 ? Array(Set(found)).sorted() : found
        return children.map {
            LinkedChild(
                node: $0,
                file: file,
                location: edge.location,
                layers: layers,
                startsEmpty: sheet != nil,
                suppressions: ignored,
            )
        }
    }

    private static func layer(for kind: Boundary.Kind) -> Layer? {
        switch kind {
        case .presentation:
            return nil
        case .navigationDestination:
            return .navigationDestination
        case .navigationStack(let type):
            return type.isDeclared ? nil : .navigationStack
        }
    }

    private func targets(of edge: Edge, file: Int) -> [Int] {
        if let hosting = edge.unlessHosting, types.isHosting(hosting) {
            return []
        }
        let receiver = edge.receiver.flatMap(memberTypes.type(of:))
        switch edge.target {
        case .type(let type):
            return lookup(.type(type), file: file)
        case .extensionFunction(let name):
            if let receiver, receiver.isFramework(oneOf: Frameworks.nonViewTypes) || types.isDeclaredNonView(receiver) {
                return []
            }
            return lookup(.extensionFunction(name), file: file)
        case .member(let member):
            let isNode = index.memberBaseNames.contains(member.base)
            guard let receiver else {
                return isNode
                    ? types.protocols(requiring: member.base).flatMap { lookupMember(member, of: $0, file: file) } : []
            }
            if receiver.isFramework(oneOf: Frameworks.nonViewTypes) {
                return []
            }
            let members = isNode ? lookupMember(member, of: receiver, file: file) : []
            guard members.isEmpty, case .called = member.labels,
                let returned = memberTypes.type(of: .memberChain(MemberChain(base: receiver, members: [member.base])))
            else { return members }
            return lookup(.type(returned), file: file)
        }
    }

    private func lookupMember(_ member: MemberName, of owner: TypeName, file: Int) -> [Int] {
        var result = lookup(.member(owner: owner, name: member), file: file)
        if types.requires(owner, member: member.base) {
            for conformer in types.conformers(of: owner) {
                result += lookup(.member(owner: conformer, name: member), file: file)
            }
        }
        if result.isEmpty {
            for proto in types.conformances(of: owner) where types.isProtocol(proto) {
                result += lookup(.member(owner: proto, name: member), file: file)
            }
        }
        return result
    }

    private func lookup(_ name: NodeName, file: Int) -> [Int] {
        let candidates = index.candidates(named: name)
        guard candidates.count > 1 else { return candidates }
        let module = files[file].file.module
        let sameModule = candidates.filter { index.nodes[$0].module == module }
        if !sameModule.isEmpty {
            return sameModule
        }
        let imports = Set(files[file].summary.imports)
        let imported = candidates.filter { imports.contains(index.nodes[$0].module) }
        return imported.isEmpty ? candidates : imported
    }

    private mutating func slotNeeds(_ owner: TypeName, file: Int) -> Set<TypeName> {
        let key = ModuleType(module: files[file].file.module, type: owner)
        if let cached = slotNeeds[key] {
            return cached
        }
        slotNeeds[key] = []
        var slots: [Set<TypeName>] = []
        for slot in lookup(.type(owner), file: file).flatMap({ index.nodes[$0].slots }) {
            slots.append(needs(providedBy: slot, file: file))
        }
        var shared: Set<TypeName> = []
        if let first = slots.first {
            shared = slots.dropFirst().reduce(first) { $0.intersection($1) }
        }
        slotNeeds[key] = shared
        return shared
    }

    private mutating func needs(providedBy provisions: some Sequence<Provision>, file: Int) -> Set<TypeName> {
        var result: Set<TypeName> = []
        for provision in provisions {
            if case .container(let owner) = provision {
                result.formUnion(slotNeeds(owner, file: file))
            } else if let type = memberTypes.type(providedBy: provision) {
                result.insert(type)
            } else {
                result.formUnion(providerNeeds[provision, default: []])
            }
        }
        return result
    }

    private static func providerNeeds(_ nodes: [GraphNode], memberTypes: MemberTypes) -> [Provision: Set<TypeName>] {
        var provisionsByProvider: [Provision: Set<Provision>] = [:]
        for node in nodes {
            switch node.name {
            case .extensionFunction(let name):
                provisionsByProvider[.extensionFunction(name), default: []].formUnion(node.provisions)
            case .type(let type) where node.isViewModifier:
                provisionsByProvider[.modifier(type), default: []].formUnion(node.provisions)
            case .type, .member:
                continue
            }
        }
        var resolved = provisionsByProvider.mapValues { Set($0.compactMap(memberTypes.type(providedBy:))) }
        var changed = true
        while changed {
            changed = false
            for (provider, provisions) in provisionsByProvider {
                for provision in provisions where provision.isProvider {
                    let nested = resolved[provision, default: []]
                    guard !nested.isSubset(of: resolved[provider, default: []]) else { continue }
                    resolved[provider, default: []].formUnion(nested)
                    changed = true
                }
            }
        }
        return resolved
    }
}

extension Provision {
    var isProvider: Bool {
        switch self {
        case .modifier, .extensionFunction:
            return true
        case .value, .container:
            return false
        }
    }
}
