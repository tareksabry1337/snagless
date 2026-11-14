package enum NodeName: Hashable, Comparable, CustomStringConvertible {
    case type(TypeName)
    case member(owner: TypeName, name: MemberName)
    case extensionFunction(String)

    package var description: String {
        switch self {
        case .type(let type):
            return type.description
        case .member(let owner, let name):
            return owner.description + "." + name.description
        case .extensionFunction(let name):
            return "." + name + "()"
        }
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.description < rhs.description
    }
}
