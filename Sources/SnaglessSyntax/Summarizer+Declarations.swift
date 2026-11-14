import SnaglessModel
import SwiftSyntax

extension Summarizer {
    func visitStruct(_ decl: StructDeclSyntax, outer: Scope) {
        var scope = typeScope(
            name: decl.name.text,
            members: decl.memberBlock,
            generics: decl.genericParameterClause,
            outer: outer,
        )
        let type = TypeName(path: scope.chain[0])
        let inherited = inheritedTypes(decl.inheritanceClause, scope: scope)
        func conforms(to names: Set<String>) -> Bool {
            inherited.contains { TypeReference.names($0.path, oneOf: names) }
        }
        let isView = conforms(to: SwiftUIAPI.viewConformances)
        declareType(type, kind: .value, inherited: inherited, members: decl.memberBlock, scope: scope, isView: isView)
        let location = location(of: decl.name)
        if conforms(to: ["App"]) {
            scope.sink = .root(appendRoot(RootSummary(origin: .app(type), scope: scope.lexical, location: location)))
        } else if conforms(to: ["PreviewProvider"]) {
            let root = RootSummary(origin: .preview(title: type.path), scope: scope.lexical, location: location)
            scope.sink = .root(appendRoot(root))
        } else if isView {
            summary.nodes.append(
                NodeSummary(
                    name: .type(type),
                    isViewModifier: conforms(to: ["ViewModifier"]),
                    scope: scope.lexical,
                    location: location,
                    requirements: requirements(decl.memberBlock, scope: scope),
                )
            )
            scope.sink = .node(summary.nodes.count - 1)
            scope.memberOwner = type
            scope.ownerIsView = true
            scope.ownerMakesControllers = conforms(to: SwiftUIAPI.controllerRepresentables)
            scope.slotNames = contentSlotNames(decl)
        } else if conforms(to: ["Widget"]) {
            let root = RootSummary(origin: .widget(name: type.path), scope: scope.lexical, location: location)
            scope.sink = .root(appendRoot(root))
        } else {
            scope.memberOwner = type
        }
        summarizeMembers(decl.memberBlock, scope: scope)
    }

    func visitPlainType(
        _ decl: some DeclGroupSyntax & NamedDeclSyntax & WithGenericParametersSyntax,
        kind: TypeKind,
        outer: Scope,
    ) {
        var scope = typeScope(
            name: decl.name.text,
            members: decl.memberBlock,
            generics: decl.genericParameterClause,
            outer: outer,
        )
        let type = TypeName(path: scope.chain[0])
        let inherited = inheritedTypes(decl.inheritanceClause, scope: scope)
        declareType(type, kind: kind, inherited: inherited, members: decl.memberBlock, scope: scope)
        scope.memberOwner = type
        if kind == .class {
            scope.enclosingClass = type
            scope.superclass = inherited.first
        }
        summarizeMembers(decl.memberBlock, scope: scope)
    }

    func visitProtocol(_ decl: ProtocolDeclSyntax, outer: Scope) {
        let scope = typeScope(name: decl.name.text, members: decl.memberBlock, generics: nil, outer: outer)
        var requirements: [String] = []
        for member in decl.memberBlock.membersInEveryBranch {
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                requirements.append(function.name.text)
            } else if let variable = member.decl.as(VariableDeclSyntax.self) {
                for binding in variable.bindings {
                    requirements += binding.pattern.boundNames
                }
            }
        }
        summary.types.append(
            TypeSummary(
                name: TypeName(path: scope.chain[0]),
                kind: .protocol,
                scope: scope.lexical,
                inherited: inheritedTypes(decl.inheritanceClause, scope: scope),
                protocolRequirements: requirements,
            )
        )
    }

    func visitExtension(_ decl: ExtensionDeclSyntax, outer: Scope) {
        guard let extended = TypeReference.path(of: decl.extendedType) else {
            summarize(Syntax(decl.memberBlock), provided: [], scope: Scope(ownerName: outer.ownerName))
            return
        }
        let type = TypeName(path: extended)
        let framework = TypeReference.frameworkName(extended)
        var scope = Scope(ownerName: type.lastComponent)
        scope.chain = [extended]
        scope.lexical = register(scope.chain)
        let inherited = inheritedTypes(decl.inheritanceClause, scope: scope)
        if framework == "View" || framework == "Scene" {
            declareType(type, kind: .extension, inherited: inherited, members: nil, scope: scope)
            visitModifierExtension(decl, scope: scope)
            return
        }
        scope.properties = propertyTable(decl.memberBlock, scope: scope)
        declareType(type, kind: .extension, inherited: inherited, members: decl.memberBlock, scope: scope)
        if framework == "EnvironmentValues" {
            recordEnvironmentValues(decl.memberBlock, scope: scope)
        }
        scope.memberOwner = type
        summarizeMembers(decl.memberBlock, scope: scope)
    }

    private func typeScope(
        name: String,
        members: MemberBlockSyntax,
        generics: GenericParameterClauseSyntax?,
        outer: Scope,
    ) -> Scope {
        var scope = Scope(ownerName: name)
        scope.chain = [outer.chain.first.map { $0 + "." + name } ?? name] + outer.chain
        scope.lexical = register(scope.chain)
        scope.generics = outer.generics.union(generics?.parameters.map(\.name.text) ?? [])
        scope.properties = propertyTable(members, scope: scope)
        return scope
    }

    private func register(_ chain: [String]) -> Int {
        if let index = scopeIndices[chain] {
            return index
        }
        summary.scopes.append(chain)
        scopeIndices[chain] = summary.scopes.count - 1
        return summary.scopes.count - 1
    }

    private func inheritedTypes(_ clause: InheritanceClauseSyntax?, scope: Scope) -> [TypeName] {
        guard let clause else { return [] }
        return clause.inheritedTypes.compactMap { reference($0.type, scope: scope) }
    }

    private func declareType(
        _ name: TypeName,
        kind: TypeKind,
        inherited: [TypeName],
        members: MemberBlockSyntax?,
        scope: Scope,
        isView: Bool = false,
    ) {
        summary.types.append(
            TypeSummary(
                name: name,
                kind: kind,
                scope: scope.lexical,
                isView: isView,
                inherited: inherited,
                memberTypes: members.map { memberTypes($0, scope: scope) } ?? [:],
                crashingDefault: members.flatMap { crashingDefault(inherited, members: $0) },
            )
        )
    }

    private func crashingDefault(_ inherited: [TypeName], members: MemberBlockSyntax) -> SnaglessModel.SourceLocation? {
        guard inherited.contains(where: { TypeReference.names($0.path, oneOf: ["EnvironmentKey"]) }) else {
            return nil
        }
        for member in members.membersInEveryBranch {
            guard let variable = member.decl.as(VariableDeclSyntax.self), variable.containsCrashingCall,
                let binding = variable.bindings.first(where: { $0.pattern.boundNames == ["defaultValue"] })
            else { continue }
            return location(of: binding.pattern)
        }
        return nil
    }

    private func contentSlotNames(_ decl: StructDeclSyntax) -> Set<String> {
        let generics = Set(decl.genericParameterClause?.parameters.map(\.name.text) ?? [])
        var names: Set<String> = []
        for member in decl.memberBlock.membersInEveryBranch {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings where binding.accessorBlock == nil {
                guard let type = binding.typeAnnotation?.type,
                    let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                else { continue }
                let path = TypeReference.path(of: type)
                if TypeReference.isFunction(type) || path.map(generics.contains) == true
                    || TypeReference.names(path, oneOf: ["AnyView"])
                {
                    names.insert(name)
                }
            }
        }
        return names
    }

    private func recordEnvironmentValues(_ members: MemberBlockSyntax, scope: Scope) {
        for member in members.membersInEveryBranch {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                let binding = variable.bindings.first,
                let name = binding.pattern.boundNames.first
            else { continue }
            if variable.attributes.contains(named: ["Entry"]) {
                if let value = binding.initializer, value.containsCrashingCall {
                    summary.crashingEntries[name] = location(of: binding.pattern)
                }
            } else if let key = subscriptKeyType(Syntax(variable), scope: scope) {
                summary.environmentKeys[name] = ScopedType(type: key, scope: scope.lexical)
            }
        }
    }

    private func subscriptKeyType(_ node: Syntax, scope: Scope) -> TypeName? {
        if let subscriptCall = node.as(SubscriptCallExprSyntax.self), subscriptCall.calledExpression.isSelf,
            let argument = subscriptCall.arguments.first?.expression.as(MemberAccessExprSyntax.self),
            argument.declName.baseName.text == "self", let base = argument.base
        {
            return staticType(base, scope: scope)
        }
        for child in node.children(viewMode: .sourceAccurate) {
            if let found = subscriptKeyType(child, scope: scope) {
                return found
            }
        }
        return nil
    }

    private func visitModifierExtension(_ decl: ExtensionDeclSyntax, scope: Scope) {
        for member in decl.memberBlock.membersInEveryBranch {
            guard let function = member.decl.as(FunctionDeclSyntax.self), function.body != nil else {
                summarize(Syntax(member.decl), provided: [], scope: scope)
                continue
            }
            summary.nodes.append(
                NodeSummary(
                    name: .extensionFunction(function.name.text),
                    isViewModifier: false,
                    scope: scope.lexical,
                    location: location(of: function.name),
                    requirements: [],
                )
            )
            var functionScope = scope
            functionScope.sink = .node(summary.nodes.count - 1)
            functionScope.ownerName = function.name.text
            summarize(Syntax(function), provided: [], scope: functionScope)
        }
    }

    private func summarizeMembers(_ members: MemberBlockSyntax, scope: Scope) {
        for member in members.membersInEveryBranch {
            let decl = Syntax(member.decl)
            if decl.isTypeDeclaration {
                summarize(decl, provided: [], scope: scope)
                continue
            }
            if scope.ownerMakesControllers, let function = member.decl.as(FunctionDeclSyntax.self),
                SwiftUIAPI.controllerMakers.contains(function.name.text)
            {
                embeddedHostingCalls.formUnion(returnedHostingCalls(function, scope: scope))
                summarize(decl, provided: [], scope: scope)
                continue
            }
            var memberScope = scope
            if let owner = scope.memberOwner,
                let helper = helperName(member.decl, viewReturningOnly: !scope.ownerIsView),
                helper.base != "body"
            {
                summary.nodes.append(
                    NodeSummary(
                        name: .member(owner: owner, name: helper),
                        isViewModifier: false,
                        scope: scope.lexical,
                        location: location(of: member.decl),
                        requirements: [],
                    )
                )
                memberScope.sink = .node(summary.nodes.count - 1)
            }
            summarize(decl, provided: [], scope: memberScope)
        }
    }

    private func helperName(_ decl: DeclSyntax, viewReturningOnly: Bool) -> MemberName? {
        if let function = decl.as(FunctionDeclSyntax.self) {
            let returnsView = buildsView(function.attributes, returnType: function.signature.returnClause?.type)
            return !viewReturningOnly || returnsView ? MemberName(function) : nil
        }
        guard let variable = decl.as(VariableDeclSyntax.self), variable.bindings.count == 1,
            let binding = variable.bindings.first, binding.accessorBlock != nil,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
        else { return nil }
        let returnsView = buildsView(variable.attributes, returnType: binding.typeAnnotation?.type)
        return !viewReturningOnly || returnsView ? MemberName(base: identifier.identifier.text) : nil
    }

    private func buildsView(_ attributes: AttributeListSyntax, returnType: TypeSyntax?) -> Bool {
        let hasViewBuilder = attributes.contains(named: ["ViewBuilder", "SceneBuilder"])
        guard !hasViewBuilder, let returnType else { return hasViewBuilder }
        return TypeReference.names(TypeReference.path(of: returnType), oneOf: ["View", "AnyView", "Scene"])
    }

    private func memberTypes(_ members: MemberBlockSyntax, scope: Scope) -> [String: Set<TypeName>] {
        var table: [String: Set<TypeName>] = [:]
        for (name, reference) in scope.properties {
            if case .type(let type) = reference {
                table[name, default: []].insert(type)
            }
        }
        for member in members.membersInEveryBranch {
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                let type = concreteReturnType(of: function, scope: scope)
            else { continue }
            table[function.name.text, default: []].insert(type)
        }
        return table
    }
}
