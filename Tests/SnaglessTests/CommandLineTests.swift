import SnaglessAnalysis
import SnaglessDriver
import Foundation
import Testing

@Suite
struct CommandLineTests {
    @Test
    func exitCodeAndStampFollowErrors() throws {
        let directory = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.write(["Sources/App/Leaf.swift": Fixture.leafView], under: directory)
        let stamp = directory.appendingPathComponent("passed.swift")
        let app = directory.appendingPathComponent("Sources/App/App.swift")
        let arguments = ["--stamp", stamp.path, directory.path]

        try "@main struct MyApp: App { var body: some Scene { WindowGroup { Leaf() } } }"
            .write(to: app, atomically: true, encoding: .utf8)
        #expect(Snagless.main(arguments: arguments) == 1)
        #expect(!FileManager.default.fileExists(atPath: stamp.path))

        try "@main struct MyApp: App { var body: some Scene { WindowGroup { Leaf().environment(Cart()) } } }"
            .write(to: app, atomically: true, encoding: .utf8)
        #expect(Snagless.main(arguments: arguments) == 0)
        #expect(FileManager.default.fileExists(atPath: stamp.path))

        try "@main struct MyApp: App { var body: some Scene { WindowGroup { Leaf() } } }"
            .write(to: app, atomically: true, encoding: .utf8)
        #expect(Snagless.main(arguments: arguments) == 1)
        #expect(!FileManager.default.fileExists(atPath: stamp.path))
        #expect(Snagless.main(arguments: ["--no-such-option"]) == 2)
        #expect(Snagless.main(arguments: ["--version"]) == 0)
    }

    @Test
    func summaryLineCountsInSingularAndPlural() {
        let project = TestProject([
            "App.swift": "@main struct MyApp: App { var body: some Scene { WindowGroup { Leaf() } } }",
            "Leaf.swift": Fixture.leafView,
        ])
        let analysis = Analysis(project.files, options: AnalysisOptions())
        #expect(
            Snagless.summaryLine(analysis, fileCount: 1, errors: 1, warnings: 2)
                == "snagless: 1 file (0 with syntax errors), 1 view, 1 edge, 1 requirement, 1 root, "
                + "1 reachable view, 0 unresolved injections, 1 fixpoint pass, 1 error, 2 warnings, "
                + "0 ignored by comments\n"
        )
        let nested = TestProject([
            "App.swift": "@main struct MyApp: App { var body: some Scene { WindowGroup { Badge() } } }",
            "Badge.swift": "struct Badge: View { var body: some View { Leaf() } }",
            "Leaf.swift": Fixture.leafView,
        ])
        let nestedAnalysis = Analysis(nested.files, options: AnalysisOptions())
        #expect(
            Snagless.summaryLine(nestedAnalysis, fileCount: 3, errors: 0, warnings: 0)
                == "snagless: 3 files (0 with syntax errors), 2 views, 2 edges, 1 requirement, 1 root, "
                + "2 reachable views, 0 unresolved injections, 2 fixpoint passes, 0 errors, 0 warnings, "
                + "0 ignored by comments\n"
        )
    }
}
