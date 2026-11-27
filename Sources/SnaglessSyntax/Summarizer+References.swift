import SnaglessModel
import SwiftSyntax

extension Summarizer {
    func reference(_ type: TypeSyntax, scope: Scope) -> TypeName? {
        TypeReference.path(of: type).flatMap { scoped($0, scope: scope) }
    }

    func staticType(_ expression: ExprSyntax, scope: Scope) -> TypeName? {
        TypeReference.path(of: expression).flatMap { scoped($0, scope: scope) }
    }

    func declaredValue(_ type: TypeSyntax?, scope: Scope) -> ValueReference? {
        guard let type, let name = reference(type, scope: scope) else { return nil }
        return TypeReference.mayBeNil(type) ? .optional(.type(name)) : .type(name)
    }

    func declaredOrInitialValue(_ type: TypeSyntax?, initializer: ExprSyntax?, scope: Scope) -> ValueReference? {
        declaredValue(type, scope: scope) ?? initializer.flatMap { valueReference($0, scope: scope) }
    }

    func scoped(_ path: String, scope: Scope) -> TypeName? {
        let head = path.prefix { $0 != "." }
        if scope.generics.contains(String(head)) {
            return nil
        }
        guard head == "Self" else { return TypeName(path: path) }
        return scope.chain.first.map { TypeName(path: $0 + path.dropFirst(head.count)) }
    }

    func constructedType(_ callee: ExprSyntax, scope: Scope) -> TypeName? {
        if let type = staticType(callee, scope: scope) {
            return type
        }
        if let access = callee.as(MemberAccessExprSyntax.self), access.declName.baseName.text == "init",
            let base = access.base
        {
            return staticType(base, scope: scope)
        }
        return nil
    }

    func valueReference(_ expression: ExprSyntax, scope: Scope) -> ValueReference? {
        let reference = possiblyOptionalReference(expression.unwrapped, scope: scope)
        guard let operand = expression.forceUnwrappedOperand, !operand.chainsOptionally else { return reference }
        return reference?.asUnwrapped
    }

    private func possiblyOptionalReference(_ expression: ExprSyntax, scope: Scope) -> ValueReference? {
        if let call = expression.as(FunctionCallExprSyntax.self) {
            if let constructed = staticType(call.calledExpression, scope: scope) {
                return .type(constructed)
            }
            if let access = call.calledExpression.as(MemberAccessExprSyntax.self), let base = access.base,
                let type = staticType(base, scope: scope)
            {
                let member = access.declName.baseName.text
                return member == "init" ? .type(type) : .memberChain(MemberChain(base: type, members: [member]))
            }
            if let name = call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                isMemberName(name, scope: scope)
            {
                return .call(
                    FunctionCall(owner: enclosingType(scope), name: name, members: [], topLevelReturnType: nil)
                )
            }
        }
        if let access = expression.as(MemberAccessExprSyntax.self), let base = access.base {
            if base.isSelf {
                return memberReference(access.declName.baseName.text, scope: scope)
            }
            if let type = staticType(expression, scope: scope) {
                return .type(type)
            }
            if let type = staticType(base, scope: scope) {
                return .memberChain(MemberChain(base: type, members: [access.declName.baseName.text]))
            }
        }
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            switch scope.locals[reference.baseName.text] {
            case .typed(let local):
                return local
            case .untyped:
                return nil
            case nil:
                return memberReference(reference.baseName.text, scope: scope)
            }
        }
        if let sequence = expression.as(SequenceExprSyntax.self) {
            return sequenceReference(Array(sequence.elements), scope: scope)
        }
        return memberChain(expression, scope: scope)
    }

    private func sequenceReference(_ elements: [ExprSyntax], scope: Scope) -> ValueReference? {
        guard elements.count >= 3, let last = elements.last else { return nil }
        let operation = elements[elements.count - 2]
        if let cast = operation.as(UnresolvedAsExprSyntax.self), cast.questionOrExclamationMark == nil,
            elements.count == 3,
            let type = last.as(TypeExprSyntax.self)
        {
            return reference(type.type, scope: scope).map(ValueReference.type)
        }
        guard let ternary = operation.as(UnresolvedTernaryExprSyntax.self),
            let whenTrue = valueReference(ternary.thenExpression, scope: scope),
            let whenFalse = valueReference(last, scope: scope)
        else { return nil }
        return whenTrue == whenFalse ? whenTrue : .ternary(whenTrue, whenFalse)
    }

    private func memberChain(_ expression: ExprSyntax, scope: Scope) -> ValueReference? {
        let access =
            expression.as(MemberAccessExprSyntax.self)
            ?? expression.as(FunctionCallExprSyntax.self)?.calledExpression.as(MemberAccessExprSyntax.self)
        guard let access, let base = access.base else { return nil }
        let baseReference =
            base.isSelf ? enclosingType(scope).map(ValueReference.type) : valueReference(base, scope: scope)
        let extended = baseReference.map { Self.extending($0, with: access.declName.baseName.text) }
        return base.chainsOptionally ? extended?.asOptional : extended
    }

    private static func extending(_ reference: ValueReference, with member: String) -> ValueReference {
        switch reference {
        case .type(let type):
            return .memberChain(MemberChain(base: type, members: [member]))
        case .memberChain(let chain):
            return .memberChain(MemberChain(base: chain.base, members: chain.members + [member]))
        case .call(let call):
            return .call(
                FunctionCall(
                    owner: call.owner,
                    name: call.name,
                    members: call.members + [member],
                    topLevelReturnType: call.topLevelReturnType,
                )
            )
        case .optional(let wrapped), .unwrapped(let wrapped):
            return extending(wrapped, with: member)
        case .ternary(let first, let second):
            return .ternary(extending(first, with: member), extending(second, with: member))
        }
    }

    private func memberReference(_ name: String, scope: Scope) -> ValueReference? {
        enclosingType(scope).map { .memberChain(MemberChain(base: $0, members: [name])) }
    }

    func isMemberName(_ name: String, scope: Scope) -> Bool {
        !name.isTypeName && scope.locals[name] == nil
    }

    private func enclosingType(_ scope: Scope) -> TypeName? {
        scope.chain.first.map { TypeName(path: $0) }
    }

    func concreteReturnType(of function: FunctionDeclSyntax, scope: Scope) -> TypeName? {
        guard let returnType = function.signature.returnClause?.type, !returnType.is(SomeOrAnyTypeSyntax.self) else {
            return nil
        }
        var functionScope = scope
        functionScope.generics.formUnion(function.genericParameterNames)
        return reference(returnType, scope: functionScope)
    }

    func returnsOptional(_ function: FunctionDeclSyntax) -> Bool {
        function.signature.returnClause.map { TypeReference.mayBeNil($0.type) } ?? false
    }

    func memberValues(_ members: MemberBlockSyntax, scope: Scope) -> [String: [ValueReference]] {
        var table: [String: [ValueReference]] = [:]
        for member in members.membersInEveryBranch {
            if let function = member.decl.as(FunctionDeclSyntax.self),
                let type = concreteReturnType(of: function, scope: scope)
            {
                let value = ValueReference.type(type)
                table[function.name.text, default: []].append(returnsOptional(function) ? .optional(value) : value)
            }
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            let environmentType = variable.attributes.first(named: ["Environment"])
                .flatMap { environmentAttributeType($0, scope: scope) }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                    let value = declaredValue(binding.typeAnnotation?.type, scope: scope)
                        ?? environmentType.map(ValueReference.type)
                        ?? binding.initializer.flatMap({ valueReference($0.value, scope: scope) })
                else { continue }
                table[identifier.identifier.text, default: []].append(value)
            }
        }
        return table
    }

    func requirements(_ members: MemberBlockSyntax, scope: Scope) -> [Requirement] {
        var result: [Requirement] = []
        for member in members.membersInEveryBranch {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                let binding = variable.bindings.first
            else { continue }
            let location = location(of: binding.pattern)
            for element in variable.attributes {
                guard let attribute = element.as(AttributeSyntax.self) else { continue }
                let attributeName = TypeReference.path(of: attribute.attributeName)
                if TypeReference.names(attributeName, oneOf: ["Environment"]) {
                    if let key = environmentAttributeKeyPath(attribute) {
                        summary.keyUses.append(KeyUse(name: key, kind: .read, location: location))
                        continue
                    }
                    if let annotation = binding.typeAnnotation?.type, TypeReference.isOptional(annotation) {
                        continue
                    }
                    if let type = environmentAttributeType(attribute, scope: scope) {
                        result.append(Requirement(type: type, location: location))
                    }
                } else if TypeReference.names(attributeName, oneOf: ["EnvironmentObject"]),
                    let type = binding.typeAnnotation.flatMap({ reference($0.type, scope: scope) })
                {
                    result.append(Requirement(type: type, location: location))
                }
            }
        }
        return result
    }

    private func environmentAttributeType(_ attribute: AttributeSyntax, scope: Scope) -> TypeName? {
        guard case .argumentList(let arguments) = attribute.arguments else { return nil }
        return metatypeName(arguments.first?.expression, scope: scope)
    }

    func metatypeName(_ expression: ExprSyntax?, scope: Scope) -> TypeName? {
        guard let access = expression?.as(MemberAccessExprSyntax.self), access.declName.baseName.text == "self",
            let base = access.base
        else { return nil }
        return staticType(base, scope: scope)
    }

    private func environmentAttributeKeyPath(_ attribute: AttributeSyntax) -> String? {
        guard case .argumentList(let arguments) = attribute.arguments else { return nil }
        return arguments.first?.expression.as(KeyPathExprSyntax.self)?.singlePropertyName
    }

    func recordDelegate(fromSelfExpression expression: ExprSyntax, scope: Scope) {
        guard let type = metatypeName(expression, scope: scope) else { return }
        summary.delegateTypes.append(ScopedType(type: type, scope: scope.lexical))
    }

    func recordDelegateAssignment(_ sequence: SequenceExprSyntax, scope: Scope) {
        let elements = Array(sequence.elements)
        guard elements.count == 3, elements[1].is(AssignmentExprSyntax.self) else { return }
        let target =
            elements[0].as(MemberAccessExprSyntax.self)?.declName.baseName.text
            ?? elements[0].as(DeclReferenceExprSyntax.self)?.baseName.text
        if target == "delegateClass" {
            recordDelegate(fromSelfExpression: elements[2], scope: scope)
        }
    }
}
