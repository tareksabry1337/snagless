import SnaglessModel

struct SuppressionID: Hashable {
    let file: Int
    let index: Int
}

struct SuppressionIndex {
    private struct FileLine: Hashable {
        let file: Int
        let line: Int
    }

    let all: [SuppressionID]
    private let files: [SummarizedFile]
    private let byLine: [FileLine: [SuppressionID]]

    init(_ files: [SummarizedFile]) {
        var all: [SuppressionID] = []
        var byLine: [FileLine: [SuppressionID]] = [:]
        for (file, summarized) in files.enumerated() {
            for (index, suppression) in summarized.summary.suppressions.enumerated() {
                let id = SuppressionID(file: file, index: index)
                all.append(id)
                for line in suppression.lines {
                    byLine[FileLine(file: file, line: line), default: []].append(id)
                }
            }
        }
        self.all = all
        self.files = files
        self.byLine = byLine
    }

    func suppression(_ id: SuppressionID) -> Suppression {
        files[id.file].summary.suppressions[id.index]
    }

    func path(of id: SuppressionID) -> String {
        files[id.file].file.path
    }

    func ignoredTypes(file: Int, line: Int) -> [SuppressionID] {
        byLine[FileLine(file: file, line: line), default: []].filter { writtenType($0) != nil }
    }

    func ignoring(_ type: TypeName, file: Int, line: Int) -> SuppressionID? {
        ignoredTypes(file: file, line: line).first { ignores(type, $0) }
    }

    func ignoring(key name: String, file: Int, line: Int) -> SuppressionID? {
        byLine[FileLine(file: file, line: line), default: []].first { suppression($0).subject == .key(name) }
    }

    func ignores(_ type: TypeName, _ id: SuppressionID) -> Bool {
        guard let written = writtenType(id) else { return false }
        return type.isWritten(as: written)
    }

    func writtenType(_ id: SuppressionID) -> String? {
        guard case .type(let written) = suppression(id).subject else { return nil }
        return written
    }
}

extension TypeName {
    func isWritten(as written: String) -> Bool {
        path == written || path.hasSuffix("." + written)
    }

    func isWritten(asAnyOf written: [String]) -> Bool {
        written.contains(where: isWritten(as:))
    }
}
