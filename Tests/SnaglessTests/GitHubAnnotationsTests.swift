import SnaglessDriver
import Foundation
import Testing

@Suite
struct GitHubAnnotationsTests {
    @Test
    func errorsKeepTheirTextAndAddAnnotationsWithAbsoluteEscapedPaths() {
        let keys = """
            extension EnvironmentValues {
                @Entry var session: Session = { fatalError() }()
            }
            """
        let project = TestProject([
            "App.swift": Fixture.app(showing: "Text(\"x\").environment(\\.session, Session())"),
            "Shop, Inc: Keys.swift": keys,
            "Reader.swift": """
            struct Reader: View {
                @Environment(\\.session) private var session
                var body: some View { Text("x") }
            }
            """,
        ])
        let directory = FileManager.default.currentDirectoryPath
        #expect(
            GitHubAnnotations.render(project.report().diagnostics).split(separator: "\n") == [
                "Shop, Inc: Keys.swift:2:16: error: `\\.session` has a crashing default",
                "App.swift:1:86: note: `\\.session` set here can run its default",
                "::error file=\(directory)/Shop%2C Inc%3A Keys.swift,line=2,col=16,title=Snagless::"
                    + "`\\.session` has a crashing default",
                "::notice file=\(directory)/App.swift,line=1,col=86,title=Snagless::"
                    + "`\\.session` set here can run its default",
            ]
        )
    }
}
