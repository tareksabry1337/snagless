package enum EdgeTarget: Hashable {
    case type(TypeName)
    case member(MemberName)
    case extensionFunction(String)
}

package struct Boundary: Hashable {
    package enum Kind: Hashable {
        case presentation
        case navigationStack(TypeName)
        case navigationDestination
    }

    package let kind: Kind
    package let start: Int

    package init(kind: Kind, start: Int) {
        self.kind = kind
        self.start = start
    }
}

package struct Edge {
    package let target: EdgeTarget
    package let location: SourceLocation
    package let provided: [Provision]
    package let receiver: ValueReference?
    package let unlessHosting: TypeName?
    package let boundaries: [Boundary]

    package init(
        target: EdgeTarget,
        location: SourceLocation,
        provided: [Provision],
        receiver: ValueReference?,
        unlessHosting: TypeName?,
        boundaries: [Boundary],
    ) {
        self.target = target
        self.location = location
        self.provided = provided
        self.receiver = receiver
        self.unlessHosting = unlessHosting
        self.boundaries = boundaries
    }
}
