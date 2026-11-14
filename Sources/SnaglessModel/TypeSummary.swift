package enum TypeKind: String {
    case value
    case `class`
    case `protocol`
    case `extension`
}

package struct TypeSummary {
    package let name: TypeName
    package let kind: TypeKind
    package let scope: Int
    package let isView: Bool
    package let inherited: [TypeName]
    package let memberTypes: [String: Set<TypeName>]
    package let protocolRequirements: [String]
    package let crashingDefault: SourceLocation?

    package init(
        name: TypeName,
        kind: TypeKind,
        scope: Int,
        isView: Bool = false,
        inherited: [TypeName] = [],
        memberTypes: [String: Set<TypeName>] = [:],
        protocolRequirements: [String] = [],
        crashingDefault: SourceLocation? = nil,
    ) {
        self.name = name
        self.kind = kind
        self.scope = scope
        self.isView = isView
        self.inherited = inherited
        self.memberTypes = memberTypes
        self.protocolRequirements = protocolRequirements
        self.crashingDefault = crashingDefault
    }
}
