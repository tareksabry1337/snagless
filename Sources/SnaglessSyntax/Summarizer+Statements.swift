import SnaglessModel
import SwiftSyntax

extension Summarizer {
    func summarizeStatements(_ items: CodeBlockItemListSyntax, provided: [Provision], scope: Scope) {
        var current = scope
        let hosted = mayHost ? hostedLocalNames(Syntax(items), scope: scope) : []
        for item in items {
            let node = Syntax(item.item)
            if let variable = node.as(VariableDeclSyntax.self) {
                summarizeLocalVariable(variable, provided: provided, scope: &current, hosted: hosted)
            } else if let guardStmt = node.as(GuardStmtSyntax.self) {
                summarize(Syntax(guardStmt.body), provided: provided, scope: current)
                current = bindConditions(guardStmt.conditions, provided: provided, scope: current)
            } else {
                summarize(node, provided: provided, scope: current)
            }
        }
    }

    func visitFunction(
        _ decl: some WithGenericParametersSyntax & WithOptionalCodeBlockSyntax,
        signature: FunctionSignatureSyntax,
        provided: [Provision],
        scope: Scope,
    ) {
        guard let body = decl.body else { return }
        var inner = scope
        inner.generics.formUnion(decl.genericParameterNames)
        for parameter in signature.parameterClause.parameters {
            bindParameter(parameter.firstName, parameter.secondName, type: parameter.type, in: &inner)
        }
        summarize(Syntax(body), provided: provided, scope: inner)
    }

    func visitClosure(_ closure: ClosureExprSyntax, provided: [Provision], scope: Scope) {
        var inner = scope
        switch closure.signature?.parameterClause {
        case .simpleInput(let names):
            for name in names {
                inner.locals[name.name.text] = .untyped
            }
        case .parameterClause(let clause):
            for parameter in clause.parameters {
                bindParameter(parameter.firstName, parameter.secondName, type: parameter.type, in: &inner)
            }
        case nil:
            break
        }
        summarize(Syntax(closure.statements), provided: provided, scope: inner)
    }

    private func bindParameter(
        _ firstName: TokenSyntax,
        _ secondName: TokenSyntax?,
        type: TypeSyntax?,
        in scope: inout Scope,
    ) {
        scope.locals[(secondName ?? firstName).text] = LocalBinding(declaredValue(type, scope: scope))
    }

    func visitIf(_ expr: IfExprSyntax, provided: [Provision], scope: Scope) {
        let inner = bindConditions(expr.conditions, provided: provided, scope: scope)
        summarize(Syntax(expr.body), provided: provided, scope: inner)
        if let elseBody = expr.elseBody {
            summarize(Syntax(elseBody), provided: provided, scope: scope)
        }
    }

    func visitWhile(_ stmt: WhileStmtSyntax, provided: [Provision], scope: Scope) {
        let inner = bindConditions(stmt.conditions, provided: provided, scope: scope)
        summarize(Syntax(stmt.body), provided: provided, scope: inner)
    }

    func visitFor(_ stmt: ForStmtSyntax, provided: [Provision], scope: Scope) {
        summarize(Syntax(stmt.sequence), provided: provided, scope: scope)
        var inner = scope
        let binding = LocalBinding(declaredValue(stmt.typeAnnotation?.type, scope: scope))
        for name in stmt.pattern.boundNames {
            inner.locals[name] = binding
        }
        if let whereClause = stmt.whereClause {
            summarize(Syntax(whereClause), provided: provided, scope: inner)
        }
        summarize(Syntax(stmt.body), provided: provided, scope: inner)
    }

    func visitSwitchCase(_ switchCase: SwitchCaseSyntax, provided: [Provision], scope: Scope) {
        var inner = scope
        if case .case(let label) = switchCase.label {
            for name in label.caseItems.flatMap(\.pattern.boundNames) {
                inner.locals[name] = .untyped
            }
        }
        summarize(Syntax(switchCase.statements), provided: provided, scope: inner)
    }

    private func summarizeLocalVariable(
        _ variable: VariableDeclSyntax,
        provided: [Provision],
        scope: inout Scope,
        hosted: Set<String>,
    ) {
        for binding in variable.bindings {
            let names = binding.pattern.boundNames
            var valueScope = scope
            if names.contains(where: hosted.contains) {
                valueScope.sink = .none
            }
            if let value = binding.initializer?.value {
                summarize(Syntax(value), provided: provided, scope: valueScope)
            }
            if let accessors = binding.accessorBlock {
                summarize(Syntax(accessors), provided: provided, scope: valueScope)
            }
            let isSingleName = binding.pattern.is(IdentifierPatternSyntax.self)
            let type = declaredOrInitialValue(
                binding.typeAnnotation?.type,
                initializer: binding.initializer?.value,
                scope: scope,
            )
            for name in names {
                scope.locals[name] = isSingleName ? LocalBinding(type) : .untyped
            }
        }
    }

    private func bindConditions(
        _ conditions: ConditionElementListSyntax,
        provided: [Provision],
        scope: Scope,
    ) -> Scope {
        var current = scope
        for element in conditions {
            switch element.condition {
            case .expression(let expression):
                summarize(Syntax(expression), provided: provided, scope: current)
            case .optionalBinding(let binding):
                if let value = binding.initializer?.value {
                    summarize(Syntax(value), provided: provided, scope: current)
                }
                for name in binding.pattern.boundNames {
                    let value =
                        binding.initializer?.value
                        ?? ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
                    let type = declaredOrInitialValue(binding.typeAnnotation?.type, initializer: value, scope: current)
                    current.locals[name] = LocalBinding(type)
                }
            case .matchingPattern(let pattern):
                summarize(Syntax(pattern.initializer.value), provided: provided, scope: current)
                for name in pattern.pattern.boundNames {
                    current.locals[name] = .untyped
                }
            default:
                break
            }
        }
        return current
    }
}
