import SnaglessModel

struct DeclaredTypes {
    private let declared: Set<TypeName>
    private let views: Set<TypeName>
    private let superclasses: [TypeName: TypeName]
    private let conformances: [TypeName: Set<TypeName>]
    private let protocolMembers: [TypeName: Set<String>]
    private let protocolsByMember: [String: [TypeName]]
    private let conformers: [TypeName: [TypeName]]

    init(_ files: [SummarizedFile]) {
        var declared: Set<TypeName> = []
        var views: Set<TypeName> = []
        var superclasses: [TypeName: TypeName] = [:]
        var conformances: [TypeName: Set<TypeName>] = [:]
        var protocolMembers: [TypeName: Set<String>] = [:]
        var protocolsByMember: [String: [TypeName]] = [:]
        var conformers: [TypeName: [TypeName]] = [:]
        var directConformers: [TypeName: [TypeName]] = [:]
        for type in files.flatMap(\.summary.types) {
            conformances[type.name, default: []].formUnion(type.inherited)
            switch type.kind {
            case .extension:
                continue
            case .protocol:
                protocolMembers[type.name, default: []].formUnion(type.protocolRequirements)
            case .class:
                if superclasses[type.name] == nil, let superclass = type.inherited.first {
                    superclasses[type.name] = superclass
                }
            case .value:
                break
            }
            declared.insert(type.name)
            if type.isView {
                views.insert(type.name)
            }
        }
        for (proto, members) in protocolMembers {
            for member in members {
                protocolsByMember[member, default: []].append(proto)
            }
        }
        for (type, inherited) in conformances {
            for proto in inherited where protocolMembers[proto] != nil {
                directConformers[proto, default: []].append(type)
            }
        }
        for proto in protocolMembers.keys {
            conformers[proto] = Self.allConformers(of: proto, direct: directConformers)
        }
        self.declared = declared
        self.views = views
        self.superclasses = superclasses
        self.conformances = conformances
        self.protocolMembers = protocolMembers
        self.protocolsByMember = protocolsByMember
        self.conformers = conformers
    }

    private static func allConformers(of proto: TypeName, direct: [TypeName: [TypeName]]) -> [TypeName] {
        var result: [TypeName] = []
        var seen: Set<TypeName> = [proto]
        var stack = direct[proto, default: []]
        while let type = stack.popLast() {
            guard seen.insert(type).inserted else { continue }
            result.append(type)
            stack += direct[type, default: []]
        }
        return result.sorted()
    }

    func isDeclaredNonView(_ type: TypeName) -> Bool {
        declared.contains(type) && !views.contains(type)
    }

    func isHosting(_ type: TypeName) -> Bool {
        var current: TypeName? = type
        var seen: Set<TypeName> = []
        while let type = current, seen.insert(type).inserted {
            if type.isFramework(oneOf: Frameworks.hostingTypes) {
                return true
            }
            current = superclasses[type]
        }
        return false
    }

    func isProtocol(_ type: TypeName) -> Bool {
        protocolMembers[type] != nil
    }

    func requires(_ proto: TypeName, member: String) -> Bool {
        protocolMembers[proto, default: []].contains(member)
    }

    func conformers(of proto: TypeName) -> [TypeName] {
        conformers[proto, default: []]
    }

    func conformances(of type: TypeName) -> [TypeName] {
        conformances[type, default: []].sorted()
    }

    func protocols(requiring member: String) -> [TypeName] {
        protocolsByMember[member, default: []].sorted()
    }
}

struct MemberTypes {
    private let table: [TypeName: [String: Set<TypeName>]]

    init(_ files: [SummarizedFile]) {
        var table: [TypeName: [String: Set<TypeName>]] = [:]
        for type in files.flatMap(\.summary.types) where !type.memberTypes.isEmpty {
            table[type.name, default: [:]].merge(type.memberTypes) { $0.union($1) }
        }
        self.table = table
    }

    func type(of reference: ValueReference) -> TypeName? {
        switch reference {
        case .type(let type):
            return type
        case .memberChain(let chain):
            guard let first = chain.members.first else { return chain.base }
            let start = table[chain.base]?[first]?.onlyElement
            return start.flatMap { follow(chain.members.dropFirst(), from: $0) }
        case .call(let call):
            let start = call.owner.flatMap { table[$0]?[call.name] }.map(\.onlyElement) ?? call.topLevelReturnType
            return start.flatMap { follow(call.members, from: $0) }
        }
    }

    private func follow(_ members: some Sequence<String>, from start: TypeName) -> TypeName? {
        var current = start
        for member in members {
            guard let next = table[current]?[member]?.onlyElement else { return nil }
            current = next
        }
        return current
    }

    func type(providedBy provision: Provision) -> TypeName? {
        switch provision {
        case .value(let reference):
            return type(of: reference)
        case .modifier, .extensionFunction, .container:
            return nil
        }
    }
}
