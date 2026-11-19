import SnaglessDriver
import Testing

@Suite
struct UncheckedViewTests {
    private static let app = Fixture.app(showing: "Text(\"x\")")

    @Test
    func viewWithRequirementsThatNoRootShowsIsAWarning() {
        let project = TestProject(["App.swift": Self.app, "Leaf.swift": Fixture.leafView])
        #expect(project.errors() == ["Leaf.swift:2:41: warning: `Leaf` is unchecked: no root shows it"])
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
