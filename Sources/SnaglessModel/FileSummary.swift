package struct ScopedType: Hashable {
    package let type: TypeName
    package let scope: Int

    package init(type: TypeName, scope: Int) {
        self.type = type
        self.scope = scope
    }
}

package struct TopLevelFunction {
    package let name: String
    package let returnType: TypeName

    package init(name: String, returnType: TypeName) {
        self.name = name
        self.returnType = returnType
    }
}

package struct FileSummary {
    package var hasSyntaxErrors = false
    package var imports: [String] = []
    package var scopes: [[String]] = [[]]
    package var types: [TypeSummary] = []
    package var functions: [TopLevelFunction] = []
    package var nodes: [NodeSummary] = []
    package var roots: [RootSummary] = []
    package var unresolved: [UnresolvedInjection] = []
    package var delegateTypes: [ScopedType] = []
    package var crashingEntries: [String: SourceLocation] = [:]
    package var environmentKeys: [String: ScopedType] = [:]
    package var keyUses: [KeyUse] = []
    package var suppressions: [Suppression] = []
    package var malformedSuppressions: [SourceLocation] = []

    package init() {}
}
