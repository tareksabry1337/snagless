import SnaglessAnalysis
import SnaglessDriver
import Testing

@Suite
struct UncheckedViewTests {
    private static let app = Fixture.app(showing: "Text(\"x\")")

    @Test
    func viewWithRequirementsThatNoRootShowsIsAWarning() {
        let project = TestProject(["App.swift": Self.app, "Leaf.swift": Fixture.leafView])
        #expect(project.errors() == [Fixture.leafUnchecked])
        #expect(project.notes == [])
    }

    @Test
    func viewWithoutRequirementsThatNoRootShowsIsANote() {
        let orphan = "struct Orphan: View { var body: some View { Text(\"o\") } }"
        let project = TestProject(["App.swift": Self.app, "Orphan.swift": orphan])
        #expect(project.errors() == [])
        #expect(
            project.notes == ["Orphan.swift: note: `Orphan` is unreachable from every App, preview and hosting root"]
        )
    }

    @Test
    func ignoredRequirementLeavesNothingUnchecked() {
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart // snagless: ignore Cart - shown from a registry
                var body: some View { Text("leaf") }
            }
            """
        let project = TestProject(["App.swift": Self.app, "Leaf.swift": leaf])
        #expect(project.errors() == [])
        #expect(project.analysis().stats.uncheckedViews == 0)
    }

    @Test
    func viewOnlyAPreviewShowsIsUncheckedWithPreviewsOff() {
        let preview = "#Preview { Leaf() }"
        let project = TestProject(["App.swift": Self.app, "Leaf.swift": Fixture.leafView, "Preview.swift": preview])
        let off = AnalysisOptions(previews: .off)
        #expect(
            project.errors(options: off) == [
                "Leaf.swift:2:41: warning: `Leaf` is unreachable from every App and hosting root"
            ]
        )
        #expect(project.analysis(options: off).stats.uncheckedViews == 1)
        #expect(project.analysis().stats.uncheckedViews == 0)
    }

    @Test
    func viewWithoutRequirementsOnlyAPreviewShowsIsANoteWithPreviewsOff() {
        let orphan = "struct Orphan: View { var body: some View { Text(\"o\") } }"
        let project = TestProject([
            "App.swift": Self.app, "Orphan.swift": orphan, "Preview.swift": "#Preview { Orphan() }",
        ])
        #expect(
            project.report(options: AnalysisOptions(previews: .off)).notes
                == "Orphan.swift: note: `Orphan` is unreachable from every App and hosting root\n"
        )
        #expect(project.notes == [])
    }

    @Test(arguments: [[:], ["Preview.swift": "#Preview { Text(\"p\") }"]])
    func viewsCheckedWithoutAnAppGetOneWarning(extra: [String: String]) {
        let badge = "struct Badge: View { @Environment(Cart.self) var cart; var body: some View { Text(\"b\") } }"
        let project = TestProject(["Leaf.swift": Fixture.leafView, "Badge.swift": badge].merging(extra) { $1 })
        #expect(
            project.errors() == [
                "Badge.swift:1:50: warning: `Badge` and 1 other view that read the environment are unchecked; "
                    + "run Snagless on the app that shows them"
            ]
        )
        #expect(
            project.notes == [
                "Badge.swift: note: `Badge` is unreachable from every App, preview and hosting root",
                "Leaf.swift: note: `Leaf` is unreachable from every App, preview and hosting root",
            ]
        )
        #expect(project.analysis().stats.uncheckedViews == 2)
    }

    @Test
    func summaryLineCountsUncheckedViews() {
        let project = TestProject(["App.swift": Self.app, "Leaf.swift": Fixture.leafView])
        #expect(
            Snagless.summaryLine(project.analysis(), fileCount: 2, errors: 0, warnings: 1)
                == "snagless: 2 files (0 with syntax errors), 1 view, 0 edges, 1 requirement, 1 root, "
                + "0 reachable views, 1 unchecked view, 0 unresolved injections, 1 fixpoint pass, 0 errors, "
                + "1 warning, 0 ignored by comments\n"
        )
    }
}
