import SnaglessModel

struct NeedSet: Hashable {
    enum Source: Int, CaseIterable {
        case parent
        case navigationStack
    }

    private(set) var fromParent: Set<TypeName> = []
    private(set) var fromNavigationStack: Set<TypeName> = []

    init(fromParent: Set<TypeName> = [], fromNavigationStack: Set<TypeName> = []) {
        self.fromParent = fromParent
        self.fromNavigationStack = fromNavigationStack
    }

    init(_ need: TypeName, from source: Source) {
        switch source {
        case .parent:
            self.init(fromParent: [need])
        case .navigationStack:
            self.init(fromNavigationStack: [need])
        }
    }

    var all: Set<TypeName> { fromParent.union(fromNavigationStack) }

    func contains(_ need: TypeName, from source: Source) -> Bool {
        switch source {
        case .parent:
            return fromParent.contains(need)
        case .navigationStack:
            return fromNavigationStack.contains(need)
        }
    }

    mutating func formUnion(_ other: Self) -> Bool {
        let before = self
        fromParent.formUnion(other.fromParent)
        fromNavigationStack.formUnion(other.fromNavigationStack)
        return self != before
    }

    func carried(through layers: [Layer]) -> Self {
        var result = self
        for layer in layers {
            switch layer {
            case .provides(let provided):
                result.fromParent.subtract(provided)
            case .ignores(let written):
                result.fromParent = result.fromParent.filter { !$0.isWritten(asAnyOf: written) }
                result.fromNavigationStack = result.fromNavigationStack.filter { !$0.isWritten(asAnyOf: written) }
            case .navigationDestination:
                result.fromNavigationStack.formUnion(result.fromParent)
                result.fromParent = []
            case .navigationStack:
                result.fromParent.formUnion(result.fromNavigationStack)
                result.fromNavigationStack = []
            }
        }
        return result
    }
}

enum Layer: Hashable {
    case provides(Set<TypeName>)
    case ignores([String])
    case navigationDestination
    case navigationStack
}
