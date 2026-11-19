package struct MemberChain: Hashable {
    package let base: TypeName
    package let members: [String]

    package init(base: TypeName, members: [String]) {
        self.base = base
        self.members = members
    }
}

package struct FunctionCall: Hashable {
    package let owner: TypeName?
    package let name: String
    package let members: [String]
    package let topLevelReturnType: TypeName?

    package init(owner: TypeName?, name: String, members: [String], topLevelReturnType: TypeName?) {
        self.owner = owner
        self.name = name
        self.members = members
        self.topLevelReturnType = topLevelReturnType
    }
}

package indirect enum ValueReference: Hashable, Sendable {
    case type(TypeName)
    case memberChain(MemberChain)
    case call(FunctionCall)
    case optional(Self)
    case unwrapped(Self)

    package var asOptional: Self {
        switch self {
        case .optional:
            return self
        case .unwrapped(let wrapped):
            return .optional(wrapped)
        case .type, .memberChain, .call:
            return .optional(self)
        }
    }

    package var asUnwrapped: Self {
        switch self {
        case .type, .unwrapped:
            return self
        case .optional(let wrapped):
            return wrapped.asUnwrapped
        case .memberChain, .call:
            return .unwrapped(self)
        }
    }
}
