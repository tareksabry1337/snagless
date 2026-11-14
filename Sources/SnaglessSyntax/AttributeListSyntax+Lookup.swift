import SwiftSyntax

extension AttributeListSyntax {
    func first(named names: Set<String>) -> AttributeSyntax? {
        lazy.compactMap { $0.as(AttributeSyntax.self) }.first { $0.isNamed(oneOf: names) }
    }

    func contains(named names: Set<String>) -> Bool {
        contains { $0.as(AttributeSyntax.self)?.isNamed(oneOf: names) == true }
    }
}

extension AttributeSyntax {
    func isNamed(oneOf names: Set<String>) -> Bool {
        TypeReference.names(TypeReference.path(of: attributeName), oneOf: names)
    }
}
