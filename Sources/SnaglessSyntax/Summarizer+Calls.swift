import SnaglessModel
import SwiftSyntax

extension Summarizer {
    func visitMemberAccess(_ access: MemberAccessExprSyntax, provided: [Provision], scope: Scope) {
        guard let base = access.base else { return }
        let name = access.declName.baseName.text
        if base.isSelf {
            addMemberEdge(MemberName(base: name), at: access.declName, provided: provided, scope: scope)
            return
        }
        if !name.isTypeName {
            let receiver =
                staticType(base, scope: scope).map(ValueReference.type) ?? valueReference(base, scope: scope)
            addEdge(
                to: .member(MemberName(base: name)),
                at: access.declName,
                provided: provided,
                scope: scope,
                receiver: receiver,
            )
        }
        summarize(Syntax(base), provided: provided, scope: scope)
    }

    func visitCall(_ call: FunctionCallExprSyntax, provided: [Provision], scope: Scope) {
        let callee = call.calledExpression
        if embeddedHostingCalls.contains(call.position) {
            summarizeArguments(call, provided: provided, scope: scope)
            return
        }
        var argumentScope = scope
        switch hostingStart(call, scope: scope) {
        case .definite:
            addHostingRoot(call, scope: scope, candidate: nil)
            return
        case .candidate(let type):
            addHostingRoot(call, scope: scope, candidate: type)
            argumentScope.unlessHosting = type
        case .none:
            break
        }
        if let access = callee.as(MemberAccessExprSyntax.self), let base = access.base {
            let name = access.declName.baseName.text
            if !name.isTypeName, name != "init" {
                guard let type = staticType(base, scope: scope) else {
                    visitModifier(call, name: access.declName, base: base, provided: provided, scope: argumentScope)
                    return
                }
                addEdge(
                    to: .member(MemberName(name, calledWith: call)),
                    at: access.declName,
                    provided: provided,
                    scope: scope,
                    receiver: .type(type),
                )
                summarizeArguments(call, provided: provided, scope: argumentScope)
                return
            }
        }
        if let reference = callee.as(DeclReferenceExprSyntax.self), !reference.baseName.text.isTypeName {
            visitModifier(call, name: reference, base: nil, provided: provided, scope: argumentScope)
            return
        }
        guard let target = constructedType(callee, scope: scope) else {
            summarize(Syntax(callee), provided: provided, scope: scope)
            summarizeArguments(call, provided: provided, scope: argumentScope)
            return
        }
        addEdge(to: .type(target), at: call, provided: provided, scope: scope)
        if target.lastComponent == SwiftUIAPI.navigationStack {
            argumentScope.boundaries.append(Boundary(kind: .navigationStack(target), start: provided.count))
        }
        summarizeArguments(call, provided: provided + [.container(target)], scope: argumentScope)
    }

    private func visitModifier(
        _ call: FunctionCallExprSyntax,
        name: DeclReferenceExprSyntax,
        base: ExprSyntax?,
        provided: [Provision],
        scope: Scope,
    ) {
        let modifier = name.baseName.text
        let member = MemberName(modifier, calledWith: call)
        let receiver: ValueReference?
        if let base, !base.isSelf {
            receiver = valueReference(base, scope: scope)
            if !SwiftUIAPI.injectionModifiers.contains(modifier), modifier != SwiftUIAPI.customModifier {
                addEdge(to: .member(member), at: name, provided: provided, scope: scope, receiver: receiver)
            }
        } else {
            receiver = scope.memberOwner.map(ValueReference.type)
            addMemberEdge(member, at: name, provided: provided, scope: scope)
        }
        let added = modifierProvisions(call, name: name, receiver: receiver, provided: provided, scope: scope)
        if appliesToSelf(base, scope: scope) {
            recordProvisions(added, scope: scope)
        }
        if let base {
            summarize(Syntax(base), provided: provided + added, scope: scope)
        }
        summarizeArguments(
            call,
            provided: provided,
            scope: boundaryScope(for: modifier, provided: provided, scope: scope),
        )
    }

    private func modifierProvisions(
        _ call: FunctionCallExprSyntax,
        name: DeclReferenceExprSyntax,
        receiver: ValueReference?,
        provided: [Provision],
        scope: Scope,
    ) -> [Provision] {
        let modifier = name.baseName.text
        if SwiftUIAPI.keyWriters.contains(modifier), let first = call.arguments.first, first.label == nil,
            let key = first.expression.as(KeyPathExprSyntax.self)?.singlePropertyName
        {
            summary.keyUses.append(KeyUse(name: key, kind: .write, location: location(of: first.expression)))
            return []
        }
        if SwiftUIAPI.injectionModifiers.contains(modifier) {
            return injectedProvisions(call, modifierName: name, scope: scope)
        }
        if modifier == SwiftUIAPI.customModifier, call.arguments.count == 1, let argument = call.arguments.first,
            let construction = argument.expression.unwrapped.as(FunctionCallExprSyntax.self),
            let modifierType = constructedType(construction.calledExpression, scope: scope)
        {
            return [.modifier(modifierType)]
        }
        addEdge(to: .extensionFunction(modifier), at: name, provided: provided, scope: scope, receiver: receiver)
        return [.extensionFunction(modifier)]
    }

    func visitPostfixIfConfig(_ expr: PostfixIfConfigExprSyntax, provided: [Provision], scope: Scope) {
        var added: [Provision] = []
        for clause in expr.config.clauses {
            guard case .postfixExpression(let chain) = clause.elements else { continue }
            var current: ExprSyntax? = chain
            while let link = current {
                guard let call = link.as(FunctionCallExprSyntax.self),
                    let access = call.calledExpression.as(MemberAccessExprSyntax.self)
                else {
                    summarize(Syntax(link), provided: provided, scope: scope)
                    break
                }
                let modifier = access.declName.baseName.text
                added += modifierProvisions(
                    call,
                    name: access.declName,
                    receiver: nil,
                    provided: provided,
                    scope: scope,
                )
                summarizeArguments(
                    call,
                    provided: provided,
                    scope: boundaryScope(for: modifier, provided: provided, scope: scope),
                )
                current = access.base
            }
        }
        if appliesToSelf(expr.base, scope: scope) {
            recordProvisions(added, scope: scope)
        }
        if let base = expr.base {
            summarize(Syntax(base), provided: provided + added, scope: scope)
        }
    }

    private func boundaryScope(for modifier: String, provided: [Provision], scope: Scope) -> Scope {
        var result = scope
        if let kind = SwiftUIAPI.boundaryModifiers[modifier] {
            result.boundaries.append(Boundary(kind: kind, start: provided.count))
        }
        return result
    }

    private func appliesToSelf(_ base: ExprSyntax?, scope: Scope) -> Bool {
        guard var current = base else { return true }
        while true {
            current = current.unwrapped
            if let call = current.as(FunctionCallExprSyntax.self) {
                if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
                    return !reference.baseName.text.isTypeName
                }
                guard let access = call.calledExpression.as(MemberAccessExprSyntax.self), let next = access.base else {
                    return false
                }
                current = next
            } else if let postfix = current.as(PostfixIfConfigExprSyntax.self), let next = postfix.base {
                current = next
            } else if let reference = current.as(DeclReferenceExprSyntax.self) {
                let name = reference.baseName.text
                return name == "self" || scope.locals[name] == .typed(.type(TypeName(path: "Content")))
            } else {
                return false
            }
        }
    }

    private func injectedProvisions(
        _ call: FunctionCallExprSyntax,
        modifierName: DeclReferenceExprSyntax,
        scope: Scope,
    ) -> [Provision] {
        guard call.arguments.count == 1, let argument = call.arguments.first, argument.label == nil,
            call.trailingClosure == nil
        else { return [] }
        let commentLines = [location(of: modifierName).line, call.endLocation(converter: converter).line]
        let declared = commentLines.flatMap { directives.provides[$0, default: []] }
            .compactMap {
                scoped($0, scope: scope)
            }
        var provisions = declared.map { Provision.value(.type($0)) }
        let reference = valueReference(argument.expression, scope: scope)
        if let reference {
            provisions.append(.value(reference))
        }
        switch reference {
        case .type:
            break
        case .memberChain, .call, .optional, .unwrapped, nil:
            let location = location(of: argument.expression)
            if declared.isEmpty && unresolvedLocations.insert(location).inserted {
                summary.unresolved.append(
                    UnresolvedInjection(
                        location: location,
                        text: "\(modifierName.baseName.text)(\(argument.expression.trimmedDescription))",
                        scope: scope.lexical,
                        pending: reference,
                    )
                )
            }
        }
        return provisions
    }

    func summarizeArguments(_ call: FunctionCallExprSyntax, provided: [Provision], scope: Scope) {
        for argument in call.arguments {
            summarize(Syntax(argument.expression), provided: provided, scope: scope)
        }
        if let closure = call.trailingClosure {
            summarize(Syntax(closure), provided: provided, scope: scope)
        }
        for extra in call.additionalTrailingClosures {
            summarize(Syntax(extra.closure), provided: provided, scope: scope)
        }
    }

    func addMemberEdge(_ member: MemberName, at node: some SyntaxProtocol, provided: [Provision], scope: Scope) {
        guard let owner = scope.memberOwner, isMemberName(member.base, scope: scope) else { return }
        if scope.slotNames.contains(member.base), case .node(let index) = scope.sink {
            let slot = Set(provided)
            if !summary.nodes[index].slots.contains(where: { Set($0) == slot }) {
                summary.nodes[index].slots.append(provided)
            }
        }
        addEdge(to: .member(member), at: node, provided: provided, scope: scope, receiver: .type(owner))
    }

    func addEdge(
        to target: EdgeTarget,
        at node: some SyntaxProtocol,
        provided: [Provision],
        scope: Scope,
        receiver: ValueReference? = nil,
    ) {
        let edge = Edge(
            target: target,
            location: location(of: node),
            provided: provided,
            receiver: receiver,
            unlessHosting: scope.unlessHosting,
            boundaries: scope.boundaries,
        )
        switch scope.sink {
        case .none:
            return
        case .node(let index):
            summary.nodes[index].edges.append(edge)
        case .root(let index):
            summary.roots[index].edges.append(edge)
        }
    }

    private func recordProvisions(_ provisions: [Provision], scope: Scope) {
        guard case .node(let index) = scope.sink else { return }
        summary.nodes[index].provisions.formUnion(provisions)
    }
}
