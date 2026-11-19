import SnaglessDriver
import SnaglessModel
import Foundation
import Testing

@Suite
struct SourceFileTests {
    @Test
    func deeplyNestedFilesAreReadInFullOnWorkerThreads() throws {
        let root = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        func nested(_ depth: Int) -> String {
            String(repeating: "VStack { ", count: depth) + "Leaf()" + String(repeating: " }", count: depth)
        }
        var sources = ["TooDeep.swift": "struct TooDeep: View { var body: some View { \(nested(3000)) } }"]
        for index in 0..<8 {
            sources["Deep\(index).swift"] = "struct Deep\(index): View { var body: some View { \(nested(1000)) } }"
        }
        try FileManager.default.write(sources, under: root)
        let files = try SummaryBatch(SourceFile.list([root.path])).files
        let readable = files.filter { !$0.file.path.hasSuffix("TooDeep.swift") }
        #expect(readable.count == 8)
        for file in readable {
            #expect(!file.summary.hasSyntaxErrors)
            #expect(file.summary.nodes.count == 1)
            #expect(
                Set(file.summary.nodes.flatMap(\.edges).map(\.target)) == [
                    .type(TypeName(path: "VStack")), .type(TypeName(path: "Leaf")),
                ]
            )
        }
        #expect(
            files.filter(\.summary.hasSyntaxErrors).map { URL(fileURLWithPath: $0.file.path).lastPathComponent } == [
                "TooDeep.swift"
            ]
        )
    }

    @Test
    func listingSkipsBuildFoldersAndNamesModulesByFolder() throws {
        let outer = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: outer) }
        let root = outer.appendingPathComponent("Sources/checkout/project")
        let paths = ["Sources/Feature/A.swift", "node_modules/pkg/B.swift", "App/C.swift", "D.swift", ".build/E.swift"]
        try FileManager.default.write(Dictionary(uniqueKeysWithValues: paths.map { ($0, "") }), under: root)
        let files = SourceFile.list([root.path])
        #expect(
            files.map(\.path) == ["App/C.swift", "D.swift", "Sources/Feature/A.swift"].map { root.path + "/" + $0 }
        )
        #expect(files.map(\.module) == ["App", "project", "Feature"])
    }

    @Test
    func targetGraphDecidesModules() throws {
        let root = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.write(
            [
                "Views/OtherDetail.swift":
                    "struct Detail: View { @Environment(Cart.self) private var cart; var body: some View { Text(\"x\") } }",
                "Views/Detail.swift": "struct Detail: View { var body: some View { Text(\"y\") } }",
                "Views/App.swift": Fixture.app(showing: "Detail()"),
            ],
            under: root,
        )
        func file(_ name: String) -> String { root.appendingPathComponent("Views/" + name).path }
        try FileManager.default.write(
            [
                "targets.json": """
                {"targets": [
                    {"module": "App", "files": ["\(file("App.swift"))", "\(file("Detail.swift"))", "\(file("README.md"))"]},
                    {"module": "Other", "files": ["\(file("OtherDetail.swift"))", "\(file("Detail.swift"))"]}
                ]}
                """
            ],
            under: root,
        )
        let fromGraph = try SourceFile.list(targetGraph: root.appendingPathComponent("targets.json").path)
        #expect(fromGraph.map(\.path) == [file("App.swift"), file("Detail.swift"), file("OtherDetail.swift")])
        #expect(fromGraph.map(\.module) == ["App", "App", "Other"])
        let byFolder = SourceFile.list([root.path])
        #expect(byFolder.map(\.module) == ["Views", "Views", "Views"])
        #expect(
            TestProject(files: try SummaryBatch(fromGraph).files).errors() == [
                "\(file("OtherDetail.swift")):1:59: warning: `Detail` is unreachable from every App, preview and hosting root"
            ]
        )
        #expect(
            TestProject(files: try SummaryBatch(byFolder).files).errors() == [
                "\(file("App.swift")):1:64: error: `Detail` needs `Cart`: "
                    + "App `MyApp` → Detail (\(file("OtherDetail.swift")):1)"
            ]
        )
    }
}
