import Foundation
import SnaglessDriver
import SnaglessModel
import Testing

@Suite
struct RuntimeCasesTests {
    private static let folder = Fixture.packageRoot.appendingPathComponent("RuntimeCases")

    @Test
    func snaglessReportsTheCasesTheTableSaysItReports() throws {
        let rows = try RuntimeCaseRow.table(Self.folder.appendingPathComponent("expected.tsv"))
        let switchSource = try String(
            contentsOf: Self.folder.appendingPathComponent("RuntimeCases/RuntimeCaseView.swift"),
            encoding: .utf8,
        )
        let namespaces = Dictionary(
            uniqueKeysWithValues: switchSource.matches(of: /case \.(\w+): (\w+)\./)
                .map {
                    (String($0.output.1), String($0.output.2))
                }
        )
        #expect(Set(namespaces.keys) == Set(rows.map(\.name)))

        let files = try SummaryBatch(SourceFile.list([Self.folder.appendingPathComponent("RuntimeCases").path])).files
        let errors = TestProject(files: files).errors().filter { $0.contains(": error: ") }
        let named = Set(
            errors.flatMap {
                $0.replacing(/→[^(]*/, with: "").matches(of: /([A-Z]\w*)\./).map { String($0.output.1) }
            }
        )
        #expect(
            Set(namespaces.filter { named.contains($0.value) }.keys) == Set(rows.filter(\.reported).map(\.name))
        )
    }
}

private struct RuntimeCaseRow {
    struct MalformedLine: Error {
        let line: String
    }

    let name: String
    let reported: Bool

    static func table(_ file: URL) throws -> [Self] {
        try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n")
            .filter { !$0.hasPrefix("#") }
            .map { line in
                let columns = line.split(separator: "\t").map(String.init)
                guard columns.count == 3, ["crashed", "rendered"].contains(columns[1]),
                    ["reported", "quiet"].contains(columns[2])
                else { throw MalformedLine(line: String(line)) }
                return Self(name: columns[0], reported: columns[2] == "reported")
            }
    }
}
