import SnaglessModel
import SwiftSyntax

extension Summarizer {
    enum HostingStart {
        case none
        case definite
        case candidate(TypeName)
    }

    func hostingStart(_ call: FunctionCallExprSyntax, scope: Scope) -> HostingStart {
        let callee = call.calledExpression
        let target = constructedType(callee, scope: scope)
        if TypeReference.names(target?.path, oneOf: Frameworks.hostingTypes) {
            return .definite
        }
        guard call.arguments.contains(where: { $0.label?.text == "rootView" }) else { return .none }
        if let access = callee.as(MemberAccessExprSyntax.self), access.declName.baseName.text == "init" {
            if access.base?.is(SuperExprSyntax.self) == true {
                guard let superclass = scope.superclass,
                    !TypeReference.names(superclass.path, oneOf: Frameworks.hostingTypes)
                else { return .definite }
                return .candidate(superclass)
            }
            if access.base?.isSelf == true {
                guard let enclosingClass = scope.enclosingClass else { return .definite }
                return .candidate(enclosingClass)
            }
        }
        guard let target else { return .definite }
        return .candidate(target)
    }

    func returnedHostingCalls(_ function: FunctionDeclSyntax, scope: Scope) -> Set<AbsolutePosition> {
        guard let statements = function.body?.statements, let last = statements.last else { return [] }
        var returned: ExprSyntax?
        if let returnStatement = last.item.as(ReturnStmtSyntax.self) {
            returned = returnStatement.expression?.unwrapped
        } else if statements.count == 1 {
            returned = last.item.as(ExprSyntax.self)?.unwrapped
        }
        if let local = returned?.as(DeclReferenceExprSyntax.self) {
            returned = localInitializer(named: local.baseName.text, before: last)?.unwrapped
        }
        guard let call = returned?.as(FunctionCallExprSyntax.self) else { return [] }
        switch hostingStart(call, scope: scope) {
        case .definite, .candidate:
            return [call.position]
        case .none:
            return []
        }
    }

    func hostedLocalNames(_ node: Syntax, scope: Scope) -> Set<String> {
        if node.isTypeDeclaration {
            return []
        }
        var names: Set<String> = []
        if let call = node.as(FunctionCallExprSyntax.self), !embeddedHostingCalls.contains(call.position),
            case .definite = hostingStart(call, scope: scope)
        {
            for argument in call.arguments {
                if let reference = argument.expression.as(DeclReferenceExprSyntax.self) {
                    names.insert(reference.baseName.text)
                }
            }
        }
        for child in node.children(viewMode: .sourceAccurate) {
            names.formUnion(hostedLocalNames(child, scope: scope))
        }
        return names
    }

    func addHostingRoot(_ call: FunctionCallExprSyntax, scope: Scope, candidate: TypeName?) {
        let root = RootSummary(
            origin: .hosting(enclosing: scope.ownerName),
            scope: scope.lexical,
            location: location(of: call),
            hostingCandidate: candidate,
        )
        let rootScope = startRoot(root, from: scope)
        summarizeArguments(call, provided: [], scope: rootScope)
        for argument in call.arguments {
            guard let reference = argument.expression.as(DeclReferenceExprSyntax.self),
                let initializer = localInitializer(named: reference.baseName.text, before: call)
            else { continue }
            summarize(Syntax(initializer), provided: [], scope: rootScope)
        }
    }

    func addPreviewRoot(_ node: Syntax, arguments: LabeledExprListSyntax, scope: Scope) {
        let title = arguments.first?.expression.as(StringLiteralExprSyntax.self)?.segments.trimmedDescription
        let root = RootSummary(
            origin: .preview(title: title ?? fileStem),
            scope: scope.lexical,
            location: location(of: node),
        )
        summarizeChildren(node, provided: [], scope: startRoot(root, from: scope))
    }

    func appendRoot(_ root: RootSummary) -> Int {
        summary.roots.append(root)
        return summary.roots.count - 1
    }

    private func startRoot(_ root: RootSummary, from scope: Scope) -> Scope {
        var rootScope = scope
        rootScope.unlessHosting = nil
        rootScope.boundaries = []
        rootScope.sink = .root(appendRoot(root))
        return rootScope
    }

    private func localInitializer(named name: String, before call: some SyntaxProtocol) -> ExprSyntax? {
        var current = Syntax(call).parent
        while let node = current {
            if let items = node.as(CodeBlockItemListSyntax.self) {
                for item in items.reversed() where item.endPosition <= call.position {
                    guard let variable = item.item.as(VariableDeclSyntax.self) else { continue }
                    for binding in variable.bindings {
                        if binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name,
                            let value = binding.initializer?.value
                        {
                            return value
                        }
                    }
                }
            }
            if node.is(FunctionDeclSyntax.self) || node.is(MemberBlockItemSyntax.self) {
                return nil
            }
            current = node.parent
        }
        return nil
    }
}
