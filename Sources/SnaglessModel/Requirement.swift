package struct Requirement {
    package let type: TypeName
    package let location: SourceLocation

    package init(type: TypeName, location: SourceLocation) {
        self.type = type
        self.location = location
    }
}
