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

    private(set) var diagnostics: [Diagnostic] = []
    private(set) var usedSuppressions: Set<SuppressionID> = []

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
                    message: "the default of `\\.\(name)` traps, and SwiftUI runs it when the key is read"
                        + " without being set and can also run it when the key is set, so any use can crash."
                        + " Give it a default that doesn't trap (an optional or a sentinel value),"
                        + " or provide the value as a type read with `@Environment(Type.self)`.",
                    subject: "\\." + name,
                    notes: writes[name, default: []].sorted()
                        .map { write in
                            DiagnosticNote(
                                path: write.path,
                                location: write.location,
                                message: "setting `\\.\(name)` here can run its trapping default"
                                    + " (\(declaration.path):\(declaration.location.line))",
                            )
                        },
                )
            )
        }
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
