package struct UnresolvedInjection {
    package let location: SourceLocation
    package let text: String
    package let scope: Int
    package let pending: ValueReference?

    package init(location: SourceLocation, text: String, scope: Int, pending: ValueReference?) {
        self.location = location
        self.text = text
        self.scope = scope
        self.pending = pending
    }
}
