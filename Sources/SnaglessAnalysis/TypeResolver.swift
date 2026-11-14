import SnaglessModel

struct TypeResolver {
    private struct ModuleQualifiedPath {
        let module: String
        let path: String
    }

    private struct ModuleFunction: Hashable {
        let module: String
        let name: String
    }

    private let modulesByType: [String: [String]]
    private let topLevelFunctions: [ModuleFunction: Set<TypeName>]

    init(_ files: [SummarizedFile]) {
        var modules: [String: Set<String>] = [:]
        for file in files {
            for type in file.summary.types where type.kind != .extension {
                modules[type.name.path, default: []].insert(file.file.module)
            }
        }
        let types = Self(modulesByType: modules.mapValues { $0.sorted() }, topLevelFunctions: [:])
        var functions: [ModuleFunction: Set<TypeName>] = [:]
        for file in files {
            let imports = Set(file.summary.imports)
            for function in file.summary.functions {
                let returnType = types.resolve(
                    function.returnType.path,
                    chain: [],
                    module: file.file.module,
                    imports: imports,
                )
                functions[ModuleFunction(module: file.file.module, name: function.name), default: []].insert(returnType)
            }
        }
        self.init(modulesByType: types.modulesByType, topLevelFunctions: functions)
    }

    private init(modulesByType: [String: [String]], topLevelFunctions: [ModuleFunction: Set<TypeName>]) {
        self.modulesByType = modulesByType
        self.topLevelFunctions = topLevelFunctions
    }

    func topLevelReturnType(of name: String, module: String, imports: Set<String>) -> TypeName? {
        let candidates =
            topLevelFunctions[ModuleFunction(module: module, name: name)]
            ?? imports.reduce(into: []) {
                $0.formUnion(topLevelFunctions[ModuleFunction(module: $1, name: name), default: []])
            }
        return candidates.onlyElement
    }

    func resolve(_ path: String, chain: [String], module: String, imports: Set<String>) -> TypeName {
        if let found = find(path, in: chain, choose: { visibleModule($0, from: module, imports: imports) }) {
            return found
        }
        let qualified = moduleQualifiedPath(path, module: module, imports: imports)
        if let qualified,
            let found = find(
                qualified.path,
                in: [],
                choose: { $0.contains(qualified.module) ? qualified.module : nil },
            )
        {
            return found
        }
        if let found = find(path, in: chain, choose: \.first) {
            return found
        }
        guard let qualified else { return TypeName(path: path) }
        return TypeName(path: qualified.path)
    }

    private func visibleModule(_ modules: [String], from module: String, imports: Set<String>) -> String? {
        if modules.contains(module) {
            return module
        }
        return modules.first(where: imports.contains)
    }

    private func find(_ path: String, in chain: [String], choose: ([String]) -> String?) -> TypeName? {
        for candidate in chain.map({ $0 + "." + path }) + [path] {
            if let modules = modulesByType[candidate], let chosen = choose(modules) {
                return TypeName(path: candidate, module: chosen)
            }
        }
        return nil
    }

    private func moduleQualifiedPath(_ path: String, module: String, imports: Set<String>) -> ModuleQualifiedPath? {
        guard let dot = path.firstIndex(of: ".") else { return nil }
        let head = String(path[..<dot])
        guard head == module || imports.contains(head) || Frameworks.modules.contains(head) else { return nil }
        return ModuleQualifiedPath(module: head, path: String(path[path.index(after: dot)...]))
    }
}
