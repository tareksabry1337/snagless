package struct KeyUse {
    package enum Kind {
        case read
        case write
    }

    package let name: String
    package let kind: Kind
    package let location: SourceLocation

    package init(name: String, kind: Kind, location: SourceLocation) {
        self.name = name
        self.kind = kind
        self.location = location
    }
}
