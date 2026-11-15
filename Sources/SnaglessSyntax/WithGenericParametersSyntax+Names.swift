import SwiftSyntax

extension WithGenericParametersSyntax {
    var genericParameterNames: [String] {
        genericParameterClause?.parameters.map(\.name.text) ?? []
    }
}
