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

package enum ValueReference: Hashable {
    case type(TypeName)
    case memberChain(MemberChain)
    case call(FunctionCall)
}
