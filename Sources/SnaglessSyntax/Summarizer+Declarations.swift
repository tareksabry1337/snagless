import SnaglessModel
import SwiftSyntax

extension Summarizer {
    func visitStruct(_ decl: StructDeclSyntax, outer: Scope) {
        var scope = typeScope(name: decl.name.text, generics: decl.genericParameterNames, outer: outer)
        let type = TypeName(path: scope.chain[0])
        let inherited = inheritedTypes(decl.inheritanceClause, scope: scope)
        let isView = Self.conforms(inherited, to: SwiftUIAPI.viewConformances)
        declareType(type, kind: .value, inherited: inherited, members: decl.memberBlock, scope: scope, isView: isView)
        let location = location(of: decl.name)
        let requirements = requirements(decl.memberBlock, scope: scope)
        if let rootOrigin = Self.rootOrigin(type, inherited: inherited) {
            scope.sink = .root(appendRoot(RootSummary(origin: rootOrigin, scope: scope.lexical, location: location)))
        } else if isView {
            scope = viewScope(type, inherited: inherited, requirements: requirements, location: location, scope: scope)
            scope.slotNames = contentSlotNames(decl)
        } else {
            if !requirements.isEmpty {
                appendTypeNode(type, requirements: requirements, location: location, scope: scope)
            }
            scope.memberOwner = type
        }
        summarizeMembers(decl.memberBlock, scope: scope)
    }

    private static func rootOrigin(_ type: TypeName, inherited: [TypeName]) -> RootOrigin? {
        if conforms(inherited, to: ["App"]) {
            .app(type)
        } else if conforms(inherited, to: ["PreviewProvider"]) {
            .preview(title: type.path)
        } else if conforms(inherited, to: ["Widget"]) {
            .widget(name: type.path)
        } else {
            nil
        }
    }

    private static func conforms(_ inherited: [TypeName], to names: Set<String>) -> Bool {
        inherited.contains { TypeReference.names($0.path, oneOf: names) }
    }

    private func viewScope(
        _ type: TypeName,
        inherited: [TypeName],
        requirements: [Requirement],
        location: SnaglessModel.SourceLocation,
        scope: Scope,
    ) -> Scope {
        var viewScope = scope
        let node = NodeSummary(
            name: .type(type),
            isViewModifier: Self.conforms(inherited, to: ["ViewModifier"]),
            scope: scope.lexical,
            location: location,
            requirements: requirements,
        )
        viewScope.sink = .node(appendNode(node))
        viewScope.memberOwner = type
        viewScope.ownerIsView = true
        viewScope.ownerMakesControllers = Self.conforms(inherited, to: SwiftUIAPI.controllerRepresentables)
        return viewScope
    }

    @discardableResult
    private func appendTypeNode(
        _ type: TypeName,
        requirements: [Requirement],
        location: SnaglessModel.SourceLocation,
        scope: Scope,
    ) -> Int {
        appendNode(
            NodeSummary(
                name: .type(type),
                isViewModifier: false,
                scope: scope.lexical,
                location: location,
                requirements: requirements,
            )
        )
    }

    func appendNode(_ node: NodeSummary) -> Int {
        summary.nodes.append(node)
        return summary.nodes.count - 1
    }

    func visitPlainType(
        _ decl: some DeclGroupSyntax & NamedDeclSyntax & WithGenericParametersSyntax,
        kind: TypeKind,
        outer: Scope,
    ) {
        var scope = typeScope(name: decl.name.text, generics: decl.genericParameterNames, outer: outer)
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
        let scope = typeScope(name: decl.name.text, generics: [], outer: outer)
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
        let isView = Self.conforms(inherited, to: SwiftUIAPI.viewConformances)
        declareType(
            type,
            kind: .extension,
            inherited: inherited,
            members: decl.memberBlock,
            scope: scope,
            isView: isView,
        )
        if framework == "EnvironmentValues" {
            recordEnvironmentValues(decl.memberBlock, scope: scope)
        }
        let location = location(of: decl.extendedType)
        if let rootOrigin = Self.rootOrigin(type, inherited: inherited) {
            scope.sink = .root(appendRoot(RootSummary(origin: rootOrigin, scope: scope.lexical, location: location)))
        } else if isView {
            scope = viewScope(type, inherited: inherited, requirements: [], location: location, scope: scope)
        } else {
            scope.memberOwner = type
        }
        summarizeMembers(decl.memberBlock, scope: scope)
    }

    private func typeScope(name: String, generics: [String], outer: Scope) -> Scope {
        var scope = Scope(ownerName: name)
        scope.chain = [outer.chain.first.map { $0 + "." + name } ?? name] + outer.chain
        scope.lexical = register(scope.chain)
        scope.generics = outer.generics.union(generics)
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
                memberValues: members.map { memberValues($0, scope: scope) } ?? [:],
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
        let generics = Set(decl.genericParameterNames)
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
            let key = metatypeName(subscriptCall.arguments.first?.expression, scope: scope)
        {
            return key
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
            let node = NodeSummary(
                name: .extensionFunction(function.name.text),
                isViewModifier: false,
                scope: scope.lexical,
                location: location(of: function.name),
                requirements: [],
            )
            var functionScope = scope
            functionScope.sink = .node(appendNode(node))
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
                let helper = helperName(member.decl, viewReturningOnly: !scope.ownerIsView)
            {
                if helper.base != "body" {
                    let node = NodeSummary(
                        name: .member(owner: owner, name: helper),
                        isViewModifier: false,
                        scope: scope.lexical,
                        location: location(of: member.decl),
                        requirements: [],
                    )
                    memberScope.sink = .node(appendNode(node))
                } else if !scope.ownerIsView {
                    let node = appendTypeNode(
                        owner,
                        requirements: [],
                        location: location(of: member.decl),
                        scope: scope,
                    )
                    memberScope.sink = .node(node)
                }
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
}
