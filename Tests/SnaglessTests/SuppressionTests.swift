import SnaglessAnalysis
import Testing

@Suite
struct SuppressionTests {
    private static let leafNeedingCartAndStore = """
        struct Leaf: View {
            @Environment(Cart.self) private var cart
            @EnvironmentObject var store: Store
            var body: some View { Text("leaf") }
        }
        """

    private static func activeCount(_ project: TestProject) -> Int {
        Analysis(project.files, options: AnalysisOptions()).stats.activeSuppressions
    }

    @Test
    func ignoringARequirementDropsOnlyThatType() {
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart // snagless: ignore Cart - set by the host before it shows
                var body: some View { Text("leaf") }
            }
            """
        let project = TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf])
        #expect(project.errors() == [])
        #expect(Self.activeCount(project) == 1)
    }

    @Test
    func ignoringAShownViewCoversOnlyTheNamedTypeBelowIt() {
        let screen = """
            struct Screen: View {
                let mode: Mode
                var body: some View {
                    if mode == .reply {
                        Leaf() // snagless: ignore Cart — only reply mode shows it, and reply mode has a cart
                    }
                }
            }
            """
        let project = TestProject([
            "App.swift": Fixture.app(showing: "Screen(mode: .compose)"), "Screen.swift": screen,
            "Leaf.swift": Self.leafNeedingCartAndStore,
        ])
        #expect(
            project.errors() == [
                "App.swift:1:64: error: `Leaf` needs `Store`: App `MyApp` → Screen → Leaf (Leaf.swift:3)"
            ]
        )
        #expect(Self.activeCount(project) == 1)
    }

    @Test
    func aSuppressionThatMatchesNothingIsAWarning() {
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart // snagless: ignore Store - left over from an old version
                var body: some View { Text("leaf") }
            }
            """
        let project = TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf])
        #expect(
            project.errors() == [
                "App.swift:1:64: error: `Leaf` needs `Cart`: App `MyApp` → Leaf (Leaf.swift:2)",
                "Leaf.swift:2:46: warning: `// snagless: ignore Store` is unused on its line; remove it",
            ]
        )
        #expect(Self.activeCount(project) == 0)
    }

    @Test
    func aSuppressionOnAViewThatNeedsNothingIsAWarning() {
        let app = Fixture.app(showing: "Text(\"x\") /* snagless: ignore Cart - the cart is set up later */")
        #expect(
            TestProject(["App.swift": app]).errors() == [
                "App.swift:1:74: warning: `// snagless: ignore Cart` is unused on its line; remove it"
            ]
        )
    }

    @Test(arguments: [
        "// snagless: ignore", "// snagless: ignore Cart", "// snagless: ignore Cart -", "// snagless: ignore - why",
    ])
    func aSuppressionWithoutATypeAndAReasonIsAnError(comment: String) {
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart \(comment)
                var body: some View { Text("leaf") }
            }
            """
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf]).errors() == [
                Fixture.leafMissingCartFromApp,
                "Leaf.swift:2:46: error: an ignore comment needs the type it ignores and a reason,"
                    + " like `// snagless: ignore Cart - only shown after sign-in`",
            ]
        )
    }

    @Test
    func aSuppressionOnTheLineAboveCoversTheNextLine() throws {
        let leaf = try Fixture.file("IgnoreCommentOnTheLineAbove/Leaf.swift")
        #expect(TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf]).errors() == [])
    }
}
