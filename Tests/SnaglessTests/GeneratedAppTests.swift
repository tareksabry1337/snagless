import SnaglessAnalysis
import SnaglessDriver
import SnaglessModel
import Foundation
import Testing

struct ExpectedViolation: Decodable, Hashable {
    let file: String
    let line: Int
    let type: String
}

struct GeneratedApp {
    private struct Expected: Decodable {
        let added: Int
        let violations: [ExpectedViolation]
    }

    let directory: URL

    init(views: Int, seed: Int) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snagless-generated-\(views)-\(seed)-\(UUID().uuidString)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3", Fixture.packageRoot.appendingPathComponent("Scripts/generate_app.py").path,
            "--n", "\(views)", "--seed", "\(seed)", "--out", directory.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    var sources: [SourceFile] {
        SourceFile.list([directory.path])
    }

    func expectedViolations() throws -> Set<ExpectedViolation> {
        let expected = try JSONDecoder()
            .decode(
                Expected.self,
                from: Data(contentsOf: directory.appendingPathComponent("expected.json")),
            )
        let violations = Set(expected.violations)
        #expect(violations.count == expected.added)
        return violations
    }

    func reportedViolations(_ analysis: Analysis) -> Set<ExpectedViolation> {
        let prefix = directory.resolvingSymlinksInPath().path + "/"
        return Set(
            analysis.diagnostics.map { diagnostic in
                let path = URL(fileURLWithPath: diagnostic.path).resolvingSymlinksInPath().path
                #expect(path.hasPrefix(prefix))
                return ExpectedViolation(
                    file: String(path.dropFirst(prefix.count)),
                    line: diagnostic.location.line,
                    type: diagnostic.subject,
                )
            }
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

@Suite(.serialized)
struct GeneratedAppTests {
    @Test(arguments: [(500, 1), (500, 2), (500, 3), (2000, 4)])
    func everyAddedViolationIsReportedAndNothingElse(views: Int, seed: Int) throws {
        let generated = try GeneratedApp(views: views, seed: seed)
        defer { generated.remove() }
        let analysis = Analysis(SummaryBatch(generated.sources).files, options: AnalysisOptions())
        #expect(generated.reportedViolations(analysis) == (try generated.expectedViolations()))
    }

    @Test
    func outputDoesNotDependOnFileOrder() throws {
        let generated = try GeneratedApp(views: 500, seed: 5)
        defer { generated.remove() }
        let orphan = "struct Orphan: View { var body: some View { Text(\"o\") } }"
        let extras = TestProject(modules: [
            "One": [
                "Extra/Sources/One/Orphan.swift": orphan,
                "Extra/Sources/One/Factory.swift":
                    "struct Factory: View { var body: some View { Orphan().environment(makeCart()) } }",
                "Extra/Sources/One/Broken.swift": "struct Broken: View { var body: some View { Text( } ",
            ],
            "Two": ["Extra/Sources/Two/Orphan.swift": orphan],
        ])
        .files
        let files = SummaryBatch(generated.sources).files + extras
        let interleaved = files.indices.sorted { ($0 % 2, $0) < ($1 % 2, $1) }.map { files[$0] }
        let reports = [files, files.reversed(), interleaved]
            .map { ordered in
                let report = TestProject(files: ordered).report()
                return report.output + report.notes
            }
        #expect(reports[1] == reports[0])
        #expect(reports[2] == reports[0])
        #expect(
            reports[0].split(separator: "\n").filter { $0.hasPrefix("Extra/") } == [
                "Extra/Sources/One/Factory.swift:1:67: note: unresolved injection `environment(makeCart())`; "
                    + "add `// snagless: provides Type` if it provides a checked type",
                "Extra/Sources/One/Broken.swift: note: `Broken` is unreachable from every App, preview and hosting root",
                "Extra/Sources/One/Factory.swift: note: `Factory` is unreachable from every App, preview and hosting root",
                "Extra/Sources/One/Orphan.swift: note: `Orphan` is unreachable from every App, preview and hosting root",
                "Extra/Sources/Two/Orphan.swift: note: `Orphan` is unreachable from every App, preview and hosting root",
                "Extra/Sources/One/Broken.swift: note: the parser read only part of this file, so its views may be incomplete",
            ]
        )
    }
}
