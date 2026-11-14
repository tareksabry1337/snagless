import SnaglessModel

struct SuppressionAudit {
    let diagnostics: [Diagnostic]
    let active: Int

    init(
        _ files: [SummarizedFile],
        suppressions: SuppressionIndex,
        used: Set<SuppressionID>,
        links: Links,
        needs: Needs,
    ) {
        var active = used
        for child in (links.nodes + links.roots).joined() {
            let needed = needs.all[child.node].all
            for id in child.suppressions where needed.contains(where: { suppressions.ignores($0, id) }) {
                active.insert(id)
            }
        }
        var diagnostics = suppressions.all.filter { !active.contains($0) }
            .map { id in
                let subject = suppressions.suppression(id).subject
                return Diagnostic(
                    path: suppressions.path(of: id),
                    location: suppressions.suppression(id).location,
                    severity: .warning,
                    message: "`// snagless: ignore \(subject)` is unused on its line; remove it",
                    subject: subject.description,
                )
            }
        for file in files {
            for location in file.summary.malformedSuppressions {
                diagnostics.append(
                    Diagnostic(
                        path: file.file.path,
                        location: location,
                        severity: .error,
                        message: "an ignore comment needs the type it ignores and a reason,"
                            + " like `// snagless: ignore Cart - only shown after sign-in`",
                        subject: "",
                    )
                )
            }
        }
        self.diagnostics = diagnostics
        self.active = active.count
    }
}
