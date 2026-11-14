import SnaglessModel

final class FileReferenceResolver {
    private struct ScopedPath: Hashable {
        let path: String
        let scope: Int
    }

    private let resolver: TypeResolver
    private let module: String
    private let imports: Set<String>
    private let scopes: [[String]]
    private var resolved: [ScopedPath: TypeName] = [:]

    private init(_ file: borrowing SummarizedFile, resolver: TypeResolver) {
        let module = file.file.module
        let imports = Set(file.summary.imports)
        self.resolver = resolver
        self.module = module
        self.imports = imports
        scopes = file.summary.scopes.map { chain in
            chain.map { resolver.resolve($0, chain: [], module: module, imports: imports).path }
        }
    }

    static func resolve(_ file: consuming SummarizedFile, with resolver: TypeResolver) -> SummarizedFile {
        let references = FileReferenceResolver(file, resolver: resolver)
        var result = file
        result.summary.scopes = references.scopes
        result.summary.types = result.summary.types.map(references.resolve)
        result.summary.nodes = result.summary.nodes.map(references.resolve)
        result.summary.roots = result.summary.roots.map(references.resolve)
        result.summary.unresolved = result.summary.unresolved.map(references.resolve)
        result.summary.delegateTypes = result.summary.delegateTypes.map(references.resolve)
        result.summary.environmentKeys = result.summary.environmentKeys.mapValues(references.resolve)
        return result
    }

    private func type(_ written: TypeName, in scope: Int) -> TypeName {
        let key = ScopedPath(path: written.path, scope: scope)
        if let cached = resolved[key] {
            return cached
        }
        let type = resolver.resolve(written.path, chain: scopes[scope], module: module, imports: imports)
        resolved[key] = type
        return type
    }

    private func resolve(_ declaration: TypeSummary) -> TypeSummary {
        TypeSummary(
            name: type(declaration.name, in: 0),
            kind: declaration.kind,
            scope: declaration.scope,
            isView: declaration.isView,
            inherited: declaration.inherited.map { type($0, in: declaration.scope) },
            memberTypes: declaration.memberTypes.mapValues { Set($0.map { type($0, in: declaration.scope) }) },
            protocolRequirements: declaration.protocolRequirements,
            crashingDefault: declaration.crashingDefault,
        )
    }

    private func resolve(_ node: NodeSummary) -> NodeSummary {
        NodeSummary(
            name: resolve(node.name),
            isViewModifier: node.isViewModifier,
            scope: node.scope,
            location: node.location,
            requirements: node.requirements.map { requirement in
                Requirement(type: type(requirement.type, in: node.scope), location: requirement.location)
            },
            edges: node.edges.map { resolve($0, in: node.scope) },
            provisions: resolve(node.provisions, in: node.scope),
            slots: node.slots.map { resolve($0, in: node.scope) },
        )
    }

    private func resolve(_ name: NodeName) -> NodeName {
        switch name {
        case .type(let type):
            return .type(self.type(type, in: 0))
        case .member(let owner, let member):
            return .member(owner: type(owner, in: 0), name: member)
        case .extensionFunction:
            return name
        }
    }

    private func resolve(_ root: RootSummary) -> RootSummary {
        RootSummary(
            origin: resolve(root.origin),
            scope: root.scope,
            location: root.location,
            hostingCandidate: root.hostingCandidate.map { type($0, in: root.scope) },
            edges: root.edges.map { resolve($0, in: root.scope) },
        )
    }

    private func resolve(_ origin: RootOrigin) -> RootOrigin {
        switch origin {
        case .app(let name):
            return .app(type(name, in: 0))
        case .widget, .hosting, .preview:
            return origin
        }
    }

    private func resolve(_ injection: UnresolvedInjection) -> UnresolvedInjection {
        UnresolvedInjection(
            location: injection.location,
            text: injection.text,
            scope: injection.scope,
            pending: injection.pending.map { resolve($0, in: injection.scope) },
        )
    }

    private func resolve(_ scoped: ScopedType) -> ScopedType {
        ScopedType(type: type(scoped.type, in: scoped.scope), scope: 0)
    }

    private func resolve(_ edge: Edge, in scope: Int) -> Edge {
        Edge(
            target: resolve(edge.target, in: scope),
            location: edge.location,
            provided: resolve(edge.provided, in: scope),
            receiver: edge.receiver.map { resolve($0, in: scope) },
            unlessHosting: edge.unlessHosting.map { type($0, in: scope) },
            boundaries: edge.boundaries.map { resolve($0, in: scope) },
        )
    }

    private func resolve(_ boundary: Boundary, in scope: Int) -> Boundary {
        switch boundary.kind {
        case .navigationStack(let name):
            return Boundary(kind: .navigationStack(type(name, in: scope)), start: boundary.start)
        case .presentation, .navigationDestination:
            return boundary
        }
    }

    private func resolve(_ target: EdgeTarget, in scope: Int) -> EdgeTarget {
        switch target {
        case .type(let name):
            return .type(type(name, in: scope))
        case .member, .extensionFunction:
            return target
        }
    }

    private func resolve(_ provisions: Set<Provision>, in scope: Int) -> Set<Provision> {
        Set(provisions.map { resolve($0, in: scope) })
    }

    private func resolve(_ provisions: [Provision], in scope: Int) -> [Provision] {
        provisions.map { resolve($0, in: scope) }
    }

    private func resolve(_ provision: Provision, in scope: Int) -> Provision {
        switch provision {
        case .value(let reference):
            return .value(resolve(reference, in: scope))
        case .modifier(let name):
            return .modifier(type(name, in: scope))
        case .container(let name):
            return .container(type(name, in: scope))
        case .extensionFunction:
            return provision
        }
    }

    private func resolve(_ reference: ValueReference, in scope: Int) -> ValueReference {
        switch reference {
        case .type(let name):
            return .type(type(name, in: scope))
        case .memberChain(let chain):
            return .memberChain(MemberChain(base: type(chain.base, in: scope), members: chain.members))
        case .call(let call):
            return .call(
                FunctionCall(
                    owner: call.owner.map { type($0, in: scope) },
                    name: call.name,
                    members: call.members,
                    topLevelReturnType: resolver.topLevelReturnType(of: call.name, module: module, imports: imports),
                )
            )
        }
    }
}
