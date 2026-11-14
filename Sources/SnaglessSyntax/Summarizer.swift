import SnaglessModel
import Foundation
import SwiftParser
import SwiftSyntax

package final class Summarizer {
    enum Sink {
        case none
        case node(Int)
        case root(Int)
    }

    enum LocalBinding: Equatable {
        case typed(ValueReference)
        case untyped

        init(_ reference: ValueReference?) {
            if let reference {
                self = .typed(reference)
            } else {
                self = .untyped
            }
        }
    }

    struct Scope {
        var sink: Sink = .none
        var properties: [String: ValueReference] = [:]
        var locals: [String: LocalBinding] = [:]
        var ownerName: String
        var memberOwner: TypeName?
        var ownerIsView = false
        var ownerMakesControllers = false
        var superclass: TypeName?
        var enclosingClass: TypeName?
        var unlessHosting: TypeName?
        var boundaries: [Boundary] = []
        var chain: [String] = []
        var lexical = 0
        var generics: Set<String> = []
        var slotNames: Set<String> = []
    }

    static let maximumNestingLevel = 1024

    let converter: SourceLocationConverter
    let directives: CommentDirectives
    let fileStem: String
    let mayHost: Bool
    var unresolvedLocations: Set<SnaglessModel.SourceLocation> = []
    var embeddedHostingCalls: Set<AbsolutePosition> = []
    var scopeIndices: [[String]: Int] = [[]: 0]
    var summary = FileSummary()

    package static func summarize(path: String, source: String) -> FileSummary {
        var parser = Parser(source, maximumNestingLevel: maximumNestingLevel)
        let tree = SourceFileSyntax.parse(from: &parser)
        let summarizer = Summarizer(path: path, source: source, tree: tree)
        let fileScope = Scope(ownerName: summarizer.fileStem)
        summarizer.summary.hasSyntaxErrors = tree.hasError
        summarizer.summary.functions = summarizer.topLevelFunctions(tree.statements, scope: fileScope)
        summarizer.summarize(Syntax(tree.statements), provided: [], scope: fileScope)
        return summarizer.summary
    }

    private func topLevelFunctions(_ items: CodeBlockItemListSyntax, scope: Scope) -> [TopLevelFunction] {
        items.flatMap { item -> [TopLevelFunction] in
            if let function = item.item.as(FunctionDeclSyntax.self) {
                return concreteReturnType(of: function, scope: scope)
                    .map {
                        [TopLevelFunction(name: function.name.text, returnType: $0)]
                    } ?? []
            }
            guard let config = item.item.as(IfConfigDeclSyntax.self) else { return [] }
            return config.clauses.flatMap { clause -> [TopLevelFunction] in
                guard case .statements(let statements) = clause.elements else { return [] }
                return topLevelFunctions(statements, scope: scope)
            }
        }
    }

    private init(path: String, source: String, tree: SourceFileSyntax) {
        converter = SourceLocationConverter(fileName: path, tree: tree)
        directives = CommentDirectives(tree: tree, source: source, converter: converter)
        mayHost = source.contains("rootView") || source.contains("Hosting")
        fileStem = Self.stem(of: path)
        summary.suppressions = directives.suppressions
        summary.malformedSuppressions = directives.malformedSuppressions
    }

    private static func stem(of path: String) -> String {
        let name = path.lastIndex(of: "/").map { path[path.index(after: $0)...] } ?? path[...]
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return String(name) }
        return String(name[..<dot])
    }

    func location(of node: some SyntaxProtocol) -> SnaglessModel.SourceLocation {
        let location = node.startLocation(converter: converter)
        return SnaglessModel.SourceLocation(line: location.line, column: location.column)
    }

    func summarize(_ node: Syntax, provided: [Provision], scope: Scope) {
        if let decl = node.as(DeclSyntax.self) {
            summarizeDeclaration(decl, provided: provided, scope: scope)
        } else if let expr = node.as(ExprSyntax.self) {
            summarizeExpression(expr, provided: provided, scope: scope)
        } else {
            summarizeOther(node, provided: provided, scope: scope)
        }
    }

    func summarizeChildren(_ node: some SyntaxProtocol, provided: [Provision], scope: Scope) {
        for child in node.children(viewMode: .sourceAccurate) {
            summarize(child, provided: provided, scope: scope)
        }
    }

    private func summarizeDeclaration(_ decl: DeclSyntax, provided: [Provision], scope: Scope) {
        switch decl.as(DeclSyntaxEnum.self) {
        case .importDecl(let decl):
            recordImport(decl)
        case .structDecl(let decl):
            visitStruct(decl, outer: scope)
        case .classDecl(let decl):
            visitPlainType(decl, kind: .class, outer: scope)
        case .enumDecl(let decl):
            visitPlainType(decl, kind: .value, outer: scope)
        case .actorDecl(let decl):
            visitPlainType(decl, kind: .value, outer: scope)
        case .protocolDecl(let decl):
            visitProtocol(decl, outer: scope)
        case .extensionDecl(let decl):
            visitExtension(decl, outer: scope)
        case .functionDecl(let decl):
            visitFunction(decl, signature: decl.signature, provided: provided, scope: scope)
        case .initializerDecl(let decl):
            visitFunction(decl, signature: decl.signature, provided: provided, scope: scope)
        case .macroExpansionDecl(let decl) where decl.macroName.text == "Preview":
            addPreviewRoot(Syntax(decl), arguments: decl.arguments, scope: scope)
        default:
            summarizeChildren(decl, provided: provided, scope: scope)
        }
    }

    private func summarizeExpression(_ expr: ExprSyntax, provided: [Provision], scope: Scope) {
        switch expr.as(ExprSyntaxEnum.self) {
        case .closureExpr(let closure):
            visitClosure(closure, provided: provided, scope: scope)
        case .ifExpr(let expr):
            visitIf(expr, provided: provided, scope: scope)
        case .macroExpansionExpr(let expr) where expr.macroName.text == "Preview":
            addPreviewRoot(Syntax(expr), arguments: expr.arguments, scope: scope)
        case .functionCallExpr(let call):
            visitCall(call, provided: provided, scope: scope)
        case .postfixIfConfigExpr(let expr):
            visitPostfixIfConfig(expr, provided: provided, scope: scope)
        case .sequenceExpr(let sequence):
            recordDelegateAssignment(sequence, scope: scope)
            summarizeChildren(sequence, provided: provided, scope: scope)
        case .memberAccessExpr(let access) where access.declName.baseName.text == "init":
            visitInitializerReference(access, provided: provided, scope: scope)
        case .memberAccessExpr(let access):
            visitMemberAccess(access, provided: provided, scope: scope)
        case .declReferenceExpr(let reference):
            let name = reference.baseName.text
            addMemberEdge(name: name, member: MemberName(base: name), at: reference, provided: provided, scope: scope)
        default:
            summarizeChildren(expr, provided: provided, scope: scope)
        }
    }

    private func summarizeOther(_ node: Syntax, provided: [Provision], scope: Scope) {
        switch node.as(SyntaxEnum.self) {
        case .codeBlockItemList(let items):
            summarizeStatements(items, provided: provided, scope: scope)
        case .whileStmt(let stmt):
            visitWhile(stmt, provided: provided, scope: scope)
        case .forStmt(let stmt):
            visitFor(stmt, provided: provided, scope: scope)
        case .switchCase(let switchCase):
            visitSwitchCase(switchCase, provided: provided, scope: scope)
        case .attribute(let attribute):
            visitAttribute(attribute, scope: scope)
        default:
            summarizeChildren(node, provided: provided, scope: scope)
        }
    }

    private func recordImport(_ decl: ImportDeclSyntax) {
        if let first = decl.path.first {
            summary.imports.append(first.name.text)
        }
    }

    private func visitAttribute(_ attribute: AttributeSyntax, scope: Scope) {
        let name = TypeReference.path(of: attribute.attributeName)
        guard TypeReference.names(name, oneOf: ["UIApplicationDelegateAdaptor", "NSApplicationDelegateAdaptor"]),
            case .argumentList(let arguments) = attribute.arguments,
            let first = arguments.first
        else { return }
        recordDelegate(fromSelfExpression: first.expression, scope: scope)
    }

    private func visitInitializerReference(_ access: MemberAccessExprSyntax, provided: [Provision], scope: Scope) {
        guard let base = access.base, let type = staticType(base, scope: scope) else { return }
        addEdge(to: .type(type), at: access, provided: provided, scope: scope)
    }
}
