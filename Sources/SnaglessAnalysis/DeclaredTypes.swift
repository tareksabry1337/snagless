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
            if type.isView {
                views.insert(type.name)
            }
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

    func isView(_ type: TypeName) -> Bool {
        views.contains(type)
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
    private struct Value {
        let type: TypeName
        let mayBeNil: Bool
    }

    private struct Member: Equatable {
        let owner: TypeName
        let name: String
    }

    private let table: [TypeName: [String: [ValueReference]]]

    init(_ files: [SummarizedFile]) {
        var table: [TypeName: [String: [ValueReference]]] = [:]
        for type in files.flatMap(\.summary.types) where !type.memberValues.isEmpty {
            table[type.name, default: [:]].merge(type.memberValues) { $0 + $1 }
        }
        self.table = table
    }

    func type(of reference: ValueReference) -> TypeName? {
        value(of: reference, visiting: []).flatMap { $0.mayBeNil ? nil : $0.type }
    }

    func typeIgnoringNil(of reference: ValueReference) -> TypeName? {
        value(of: reference, visiting: [])?.type
    }

    private func value(of reference: ValueReference, visiting: [Member]) -> Value? {
        switch reference {
        case .type(let type):
            return Value(type: type, mayBeNil: false)
        case .memberChain(let chain):
            return follow(chain.members[...], from: Value(type: chain.base, mayBeNil: false), visiting: visiting)
        case .call(let call):
            if let owner = call.owner,
                let start = value(of: Member(owner: owner, name: call.name), visiting: visiting)
            {
                return follow(call.members[...], from: start, visiting: visiting)
            }
            return call.topLevelReturnType.flatMap {
                follow(call.members[...], from: Value(type: $0, mayBeNil: false), visiting: visiting)
            }
        case .optional(let wrapped):
            return value(of: wrapped, visiting: visiting).map { Value(type: $0.type, mayBeNil: true) }
        case .unwrapped(let wrapped):
            return value(of: wrapped, visiting: visiting).map { Value(type: $0.type, mayBeNil: false) }
        case .ternary(let first, let second):
            guard let first = value(of: first, visiting: visiting), let second = value(of: second, visiting: visiting)
            else { return nil }
            return Self.combinedIfSameType(first, second)
        }
    }

    private func value(of member: Member, visiting: [Member]) -> Value? {
        guard let references = table[member.owner]?[member.name], !visiting.contains(member) else { return nil }
        let values = references.compactMap { value(of: $0, visiting: visiting + [member]) }
        return values.dropFirst()
            .reduce(values.first) { combined, next in
                combined.flatMap { Self.combinedIfSameType($0, next) }
            }
    }

    private func follow(_ members: ArraySlice<String>, from start: Value, visiting: [Member]) -> Value? {
        var current = start
        for name in members {
            guard let next = value(of: Member(owner: current.type, name: name), visiting: visiting) else { return nil }
            current = next
        }
        return current
    }

    private static func combinedIfSameType(_ first: Value, _ second: Value) -> Value? {
        guard first.type == second.type else { return nil }
        return Value(type: first.type, mayBeNil: first.mayBeNil || second.mayBeNil)
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
