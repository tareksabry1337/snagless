import SwiftSyntax

extension KeyPathExprSyntax {
    var singlePropertyName: String? {
        guard components.count == 1, case .property(let property) = components.first?.component else { return nil }
        return property.declName.baseName.text
    }
}
