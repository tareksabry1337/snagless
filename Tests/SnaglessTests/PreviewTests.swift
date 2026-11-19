import SnaglessAnalysis
import Testing

@Suite
struct PreviewTests {
    @Test
    func previewFindingsFollowThePreviewsOption() {
        let sources = ["Leaf.swift": Fixture.leafView + "\n#Preview { Leaf() }\n"]
        let finding = "`Leaf` needs `Cart`: preview `Leaf` → Leaf (Leaf.swift:2)"
        #expect(
            TestProject(sources).errors(options: AnalysisOptions(previews: .error)) == [
                "Leaf.swift:5:12: error: " + finding
            ]
        )
        #expect(
            TestProject(sources).errors(options: AnalysisOptions(previews: .warning)) == [
                "Leaf.swift:5:12: warning: " + finding
            ]
        )
        #expect(
            TestProject(sources).errors(options: AnalysisOptions(previews: .off)) == [
                "Leaf.swift:2:41: warning: `Leaf` reads the environment and is unchecked; "
                    + "run Snagless on the app that shows it"
            ]
        )
    }

    @Test
    func previewsWithTraitsPreviewableStateAndIfDebugAreRoots() {
        let previews = """
            #Preview("Traits", traits: .sizeThatFitsLayout) {
                Leaf()
            }

            #Preview("Previewable") {
                @Previewable
                @State
                var cart = Cart()
                Leaf().environment(cart)
            }

            #if DEBUG
            #Preview("Debug") {
                Leaf()
            }
            #endif
            """
        #expect(
            TestProject(["Previews.swift": previews, "Leaf.swift": Fixture.leafView]).errors() == [
                "Previews.swift:2:5: error: `Leaf` needs `Cart`: preview `Traits` → Leaf (Leaf.swift:2)",
                "Previews.swift:14:5: error: `Leaf` needs `Cart`: preview `Debug` → Leaf (Leaf.swift:2)",
            ]
        )
    }
}
