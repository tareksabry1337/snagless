package struct TypeName: Hashable, Comparable, CustomStringConvertible {
    package let path: String
    package let module: String?

    package init(path: String, module: String? = nil) {
        self.path = path
        self.module = module
    }

    package var isDeclared: Bool { module != nil }

    package var description: String { path }

    package var lastComponent: String {
        guard let dot = path.lastIndex(of: ".") else { return path }
        return String(path[path.index(after: dot)...])
    }

    package func isFramework(oneOf names: Set<String>) -> Bool {
        !isDeclared && names.contains(path)
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.path == rhs.path else { return lhs.path < rhs.path }
        switch (lhs.module, rhs.module) {
        case let (left?, right?):
            return left < right
        case (nil, .some):
            return true
        case (_, nil):
            return false
        }
    }
}
