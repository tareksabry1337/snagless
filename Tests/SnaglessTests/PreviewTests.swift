import SnaglessAnalysis
import Testing

@Suite
struct PreviewTests {
    @Test
    func previewFindingsFollowThePreviewsOption() {
        let sources = ["Leaf.swift": Fixture.leafView + "\n#Preview { Leaf() }\n"]
        let finding = "`Leaf` is shown from preview `Leaf` without `Cart`; required by Leaf (Leaf.swift:2)."
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
        #expect(TestProject(sources).errors(options: AnalysisOptions(previews: .off)) == [])
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
                "Previews.swift:2:5: error: `Leaf` is shown from preview `Traits` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2).",
                "Previews.swift:14:5: error: `Leaf` is shown from preview `Debug` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2).",
            ]
        )
    }
}
