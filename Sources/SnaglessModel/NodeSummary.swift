package struct NodeSummary {
    package let name: NodeName
    package let isViewModifier: Bool
    package let scope: Int
    package let location: SourceLocation
    package let requirements: [Requirement]
    package var edges: [Edge]
    package var provisions: Set<Provision>
    package var slots: [[Provision]]

    package init(
        name: NodeName,
        isViewModifier: Bool,
        scope: Int,
        location: SourceLocation,
        requirements: [Requirement],
        edges: [Edge] = [],
        provisions: Set<Provision> = [],
        slots: [[Provision]] = [],
    ) {
        self.name = name
        self.isViewModifier = isViewModifier
        self.scope = scope
        self.location = location
        self.requirements = requirements
        self.edges = edges
        self.provisions = provisions
        self.slots = slots
    }
}
