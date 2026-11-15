import SnaglessModel
import SwiftParser
import SwiftSyntax

enum TypeReference {
    static func path(of type: TypeSyntax) -> String? {
        switch type.as(TypeSyntaxEnum.self) {
        case .identifierType(let identifier):
            if isOptionalName(identifier.name.text), let wrapped = identifier.genericArgumentClause?.arguments.first {
                return genericArgumentPath(wrapped)
            }
            return identifier.name.text
        case .memberType(let member):
            let name = member.name.text
            guard name != "Type", name != "Protocol", let base = path(of: member.baseType) else { return nil }
            if base == "Swift", name == "Optional", let wrapped = member.genericArgumentClause?.arguments.first {
                return genericArgumentPath(wrapped)
            }
            return base + "." + name
        case .optionalType(let optional):
            return path(of: optional.wrappedType)
        case .implicitlyUnwrappedOptionalType(let optional):
            return path(of: optional.wrappedType)
        case .someOrAnyType(let someOrAny):
            return path(of: someOrAny.constraint)
        case .attributedType(let attributed):
            return path(of: attributed.baseType)
        case .tupleType(let tuple):
            guard tuple.elements.count == 1, let only = tuple.elements.first, only.firstName == nil else { return nil }
            return path(of: only.type)
        default:
            return nil
        }
    }

    static func path(of expression: ExprSyntax) -> String? {
        switch expression.as(ExprSyntaxEnum.self) {
        case .declReferenceExpr(let reference):
            let name = reference.baseName.text
            return name.isTypeName ? name : nil
        case .memberAccessExpr(let access):
            let name = access.declName.baseName.text
            guard name.isTypeName, let base = access.base, let basePath = path(of: base) else {
                return nil
            }
            return basePath + "." + name
        case .genericSpecializationExpr(let generic):
            return path(of: generic.expression)
        case .typeExpr(let typeExpression):
            return path(of: typeExpression.type)
        default:
            return nil
        }
    }

    static func path(ofText text: String) -> String? {
        var parser = Parser(text.trimmingCharacters(in: .whitespacesAndNewlines))
        let type = TypeSyntax.parse(from: &parser)
        return type.hasError ? nil : path(of: type)
    }

    static func isOptional(_ type: TypeSyntax) -> Bool {
        switch type.as(TypeSyntaxEnum.self) {
        case .optionalType:
            return true
        case .identifierType(let identifier):
            return isOptionalName(identifier.name.text) && identifier.genericArgumentClause != nil
        case .memberType(let member):
            return member.name.text == "Optional" && member.baseType.trimmedDescription == "Swift"
        case .attributedType(let attributed):
            return isOptional(attributed.baseType)
        case .tupleType(let tuple):
            guard tuple.elements.count == 1, let only = tuple.elements.first, only.firstName == nil else {
                return false
            }
            return isOptional(only.type)
        default:
            return false
        }
    }

    static func isFunction(_ type: TypeSyntax) -> Bool {
        switch type.as(TypeSyntaxEnum.self) {
        case .functionType:
            return true
        case .attributedType(let attributed):
            return isFunction(attributed.baseType)
        case .optionalType(let optional):
            return isFunction(optional.wrappedType)
        case .tupleType(let tuple):
            guard tuple.elements.count == 1, let only = tuple.elements.first else { return false }
            return isFunction(only.type)
        default:
            return false
        }
    }

    static func frameworkName(_ path: String) -> String {
        guard let dot = path.firstIndex(of: "."), Frameworks.modules.contains(String(path[..<dot])) else { return path }
        return String(path[path.index(after: dot)...])
    }

    static func names(_ path: String?, oneOf names: Set<String>) -> Bool {
        path.map { names.contains(frameworkName($0)) } ?? false
    }

    private static func isOptionalName(_ name: String) -> Bool {
        name == "Optional"
    }

    private static func genericArgumentPath(_ argument: GenericArgumentSyntax) -> String? {
        guard case .type(let type) = argument.argument else { return nil }
        return path(of: type)
    }
}
