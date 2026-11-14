import Testing

@Suite
struct CommentDirectiveTests {
    @Test
    func providesCommentNamesWhatAnInjectionProvides() {
        let app = """
            @main struct MyApp: App {
                var body: some Scene {
                    WindowGroup {
                        Leaf()
                            .environment(makeCart()) // snagless: provides Cart
                    }
                }
            }
            """
        #expect(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [])
        #expect(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).notes == [])
    }

    @Test
    func providesCommentOnTheLineAboveCounts() throws {
        let app = try Fixture.file("ProvidesCommentOnTheLineAbove/App.swift")
        #expect(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [])
    }

    @Test
    func providesCommentInsideAStringDoesNotCount() {
        let app = Fixture.app(showing: "Leaf().environment(makeCart(\"// snagless: provides Cart\"))")
        #expect(
            TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [Fixture.leafMissingCartFromApp]
        )
        #expect(
            TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).notes == [
                "App.swift:1:83: note: unresolved injection `environment(makeCart(\"// snagless: provides Cart\"))`; "
                    + "add `// snagless: provides Type` if it provides a checked type"
            ]
        )
    }
}
