import Testing

@Suite
struct TrappingKeyTests {
    private static let keys = """
        struct RouterKey: EnvironmentKey { static var defaultValue: Router { fatalError("no router") } }
        struct SafeKey: EnvironmentKey { static let defaultValue = 0 }
        extension EnvironmentValues {
            var router: Router {
                get { self[RouterKey.self] }
                set { self[RouterKey.self] = newValue }
            }
            var safe: Int {
                get { self[SafeKey.self] }
                set { self[SafeKey.self] = newValue }
            }
            @Entry var session: Session = { fatalError() }()
        }
        """

    private static func trapping(_ key: String, at site: String) -> String {
        "Keys.swift:\(site): error: `\\.\(key)` has a crashing default"
    }

    @Test
    func aUsedTrappingKeyIsReportedOnceAtItsDefault() {
        let keyed = """
            struct Keyed: View {
                @Environment(\\.router) private var router
                @Environment(\\.safe) private var safe
                @Environment(\\.dismiss) private var dismiss
                var body: some View { Text("x") }
            }
            struct Other: View {
                @Environment(\\.router) private var router
                var body: some View { Text("y") }
            }
            """
        let app = Fixture.app(showing: "Keyed().environment(\\.safe, 1)")
        #expect(
            TestProject(["App.swift": app, "Keys.swift": Self.keys, "Keyed.swift": keyed]).errors() == [
                Self.trapping("router", at: "1:47")
            ]
        )
    }

    @Test
    func everyWriteOfATrappingKeyIsANoteOnTheOneError() {
        let writer = """
            struct Writer: View {
                var body: some View {
                    Text("x")
                        .environment(\\.session, Session())
                        .transformEnvironment(\\.session) { $0 = Session() }
                }
            }
            """
        let app = Fixture.app(showing: "Writer().environment(\\.session, Session())")
        #expect(
            TestProject(["App.swift": app, "Keys.swift": Self.keys, "Writer.swift": writer]).errors() == [
                Self.trapping("session", at: "12:16"),
                "App.swift:1:85: note: `\\.session` set here can run its default",
                "Writer.swift:4:26: note: `\\.session` set here can run its default",
                "Writer.swift:5:35: note: `\\.session` set here can run its default",
            ]
        )
    }

    @Test
    func anUnusedTrappingKeyIsQuiet() {
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Text(\"x\")"), "Keys.swift": Self.keys]).errors() == []
        )
    }

    @Test
    func anIgnoredDefaultIsQuiet() {
        let keys = """
            extension EnvironmentValues {
                @Entry var session: Session = { fatalError() }() // snagless: ignore \\.session - set at launch
            }
            """
        let app = Fixture.app(showing: "Text(\"x\").environment(\\.session, Session())")
        #expect(TestProject(["App.swift": app, "Keys.swift": keys]).errors() == [])
    }
}
