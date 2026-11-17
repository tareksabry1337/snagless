import SnaglessModel

struct TrappingKeys {
    private struct Site: Hashable, Comparable {
        let file: Int
        let path: String
        let location: SourceLocation

        static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.path, lhs.location) < (rhs.path, rhs.location)
        }
    }

    let diagnostics: [Diagnostic]
    let usedSuppressions: Set<SuppressionID>

    init(_ files: [SummarizedFile], suppressions: SuppressionIndex) {
        let declarations = Self.declarations(in: files)
        var used: Set<String> = []
        var writes: [String: Set<Site>] = [:]
        for (index, file) in files.enumerated() {
            for use in file.summary.keyUses where declarations[use.name] != nil {
                used.insert(use.name)
                if use.kind == .write {
                    writes[use.name, default: []]
                        .insert(Site(file: index, path: file.file.path, location: use.location))
                }
            }
        }
        var diagnostics: [Diagnostic] = []
        var usedSuppressions: Set<SuppressionID> = []
        for (name, declaration) in declarations where used.contains(name) {
            if let id = suppressions.ignoring(key: name, file: declaration.file, line: declaration.location.line) {
                usedSuppressions.insert(id)
                continue
            }
            diagnostics.append(
                Diagnostic(
                    path: declaration.path,
                    location: declaration.location,
                    severity: .error,
                    message: "`\\.\(name)` has a crashing default",
                    subject: "\\." + name,
                    notes: writes[name, default: []].sorted()
                        .map { write in
                            DiagnosticNote(
                                path: write.path,
                                location: write.location,
                                message: "`\\.\(name)` set here can run its default",
                            )
                        },
                )
            )
        }
        self.diagnostics = diagnostics
        self.usedSuppressions = usedSuppressions
    }

    private static func declarations(in files: [SummarizedFile]) -> [String: Site] {
        var keyTypes: [TypeName: Site] = [:]
        var result: [String: Site] = [:]
        for (index, file) in files.enumerated() {
            for type in file.summary.types {
                if let location = type.crashingDefault {
                    keyTypes[type.name] = Site(file: index, path: file.file.path, location: location)
                }
            }
            for (name, location) in file.summary.crashingEntries {
                result[name] = Site(file: index, path: file.file.path, location: location)
            }
        }
        for file in files {
            for (name, key) in file.summary.environmentKeys {
                if let site = keyTypes[key.type] {
                    result[name] = site
                }
            }
        }
        return result
    }
}
