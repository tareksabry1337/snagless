package struct Report {
    package let diagnostics: [Diagnostic]
    package let output: String
    package let notes: String

    package init(_ analysis: Analysis, verbose: Bool) {
        diagnostics = analysis.diagnostics.sorted(by: Self.outputOrder)
        output = diagnostics.map { $0.rendered + "\n" }.joined()
        guard verbose else {
            notes = ""
            return
        }
        var lines: [String] = []
        for site in analysis.unresolved.sorted(by: Self.outputOrder) {
            let note = DiagnosticNote(
                path: site.path,
                location: site.injection.location,
                message: "unresolved injection `\(site.injection.text)`; "
                    + "add `// snagless: provides Type` if it provides a checked type",
            )
            lines.append(note.rendered + "\n")
        }
        for view in analysis.unreachableViews.sorted(by: Self.outputOrder) {
            lines.append("\(view.path): note: `\(view.name)` is unreachable from every App, preview and hosting root\n")
        }
        for path in analysis.unreadablePaths {
            lines.append("\(path): note: the parser read only part of this file, so its views may be incomplete\n")
        }
        notes = lines.joined()
    }

    private static func outputOrder(_ lhs: Diagnostic, _ rhs: Diagnostic) -> Bool {
        (lhs.path, lhs.location, lhs.subject, lhs.message) < (rhs.path, rhs.location, rhs.subject, rhs.message)
    }

    private static func outputOrder(_ lhs: UnresolvedInjectionSite, _ rhs: UnresolvedInjectionSite) -> Bool {
        (lhs.path, lhs.injection.location, lhs.injection.text) < (rhs.path, rhs.injection.location, rhs.injection.text)
    }

    private static func outputOrder(_ lhs: UnreachableView, _ rhs: UnreachableView) -> Bool {
        (lhs.name.description, lhs.path) < (rhs.name.description, rhs.path)
    }
}
