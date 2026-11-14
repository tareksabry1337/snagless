package enum Provision: Hashable {
    case value(ValueReference)
    case modifier(TypeName)
    case extensionFunction(String)
    case container(TypeName)
}
