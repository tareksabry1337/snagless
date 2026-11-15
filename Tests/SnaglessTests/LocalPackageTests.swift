import SnaglessDriver
import SnaglessModel
import SnaglessSyntax
import Foundation
import Testing

@Suite
struct LocalPackageTests {
    @Test
    func manifestListsSourceTargetsAndLocalPackages() {
        let manifest = PackageManifest(
            source: """
                let package = Package(
                    name: "Shop",
                    dependencies: [
                        .package(path: "../Core"),
                        .package(name: "Money", path: "../Money"),
                        .package(url: "https://example.com/remote.git", from: "1.0.0"),
                    ],
                    targets: [
                        .target(name: "Shop", dependencies: ["Core"], path: "Code"),
                        .executableTarget(name: "ShopTool"),
                        .testTarget(name: "ShopTests", dependencies: ["Shop"]),
                        .plugin(name: "ShopPlugin", capability: .buildTool()),
                    ]
                )
                """
        )
        #expect(
            manifest.targets == [
                PackageManifest.Target(name: "Shop", path: "Code"),
                PackageManifest.Target(name: "ShopTool", path: nil),
            ]
        )
        #expect(manifest.localPackagePaths == ["../Core", "../Money"])
    }

    @Test
    func packagesAreFollowedThroughTheirOwnLocalDependencies() throws {
        let root = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let leaf = Fixture.leafView.replacingOccurrences(of: "struct Leaf", with: "public struct Leaf")
        try FileManager.default.write(
            [
                "App/App.swift": "import Shop\n" + Fixture.app(showing: "Badge()"),
                "Shop/Package.swift": """
                let package = Package(
                    name: "Shop",
                    dependencies: [.package(path: "../Core")],
                    targets: [.target(name: "Shop", dependencies: ["Core"], path: "Code")]
                )
                """,
                "Shop/Code/Badge.swift":
                    "import Core\npublic struct Badge: View { public var body: some View { Leaf() } }",
                "Shop/Tests/ShopTests/ShopTests.swift": Fixture.app(showing: "Leaf()"),
                "Core/Package.swift": "let package = Package(name: \"Core\", targets: [.target(name: \"Core\")])",
                "Core/Sources/Core/Leaf.swift": leaf,
            ],
            under: root,
        )
        func path(_ relative: String) -> String { root.appendingPathComponent(relative).path }
        let packages = SourceFile.list(packages: [path("Shop")])
        #expect(
            packages == [
                SourceFile(path: path("Core/Sources/Core/Leaf.swift"), module: "Core"),
                SourceFile(path: path("Shop/Code/Badge.swift"), module: "Shop"),
            ]
        )
        let files = SourceFile.list([path("App")]) + packages
        #expect(
            TestProject(files: try SummaryBatch(files).files).errors() == [
                "\(path("App/App.swift")):2:64: error: `Badge` is shown from App `MyApp` without `Cart`; "
                    + "required by Badge → Leaf (\(path("Core/Sources/Core/Leaf.swift")):2)."
            ]
        )
        #expect(Snagless.main(arguments: ["--package", path("Shop"), path("App")]) == 1)
        #expect(Snagless.main(arguments: [path("App")]) == 0)
    }
}
