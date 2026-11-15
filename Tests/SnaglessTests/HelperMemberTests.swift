import SnaglessModel
import SnaglessSyntax
import Testing

@Suite
struct HelperMemberTests {
    @Test
    func injectionInTheBodyReachesHelperProperties() {
        let row = """
            struct Row: View {
                var menu: some View { Leaf() }
                func detail() -> some View { Leaf() }
                var body: some View {
                    VStack { menu; self.detail() }
                        .environment(Cart.shared)
                }
                var unprovided: some View { Leaf() }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Row()"), "Row.swift": row, "Leaf.swift": Fixture.leafView,
                "Cart.swift": Fixture.cart,
            ])
            .errors() == []
        )
    }

    @Test(arguments: ["self._row", "self._row()"])
    func underscoredHelpersAreMembers(content: String) {
        let row = """
            struct Row: View {
                var body: some View { \(content) }
                var _row: some View { Leaf() }
                func _row() -> some View { Leaf() }
            }
            """
        let path = content.hasSuffix("()") ? "Row._row()" : "Row._row"
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Row()"), "Row.swift": row, "Leaf.swift": Fixture.leafView])
                .errors() == [
                    "App.swift:1:64: error: `Row` is shown from App `MyApp` without `Cart`; "
                        + "required by Row → \(path) → Leaf (Leaf.swift:2)."
                ]
        )
    }

    @Test
    func helperPropertiesInExtensionsAreChildren() {
        let row = "struct Row: View { var body: some View { header } }"
        let header = "extension Row { var header: some View { Leaf() } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Row()"), "Row.swift": row, "Row+Header.swift": header,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Row` is shown from App `MyApp` without `Cart`; "
                    + "required by Row → Row.header → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func viewBuildingMethodOnAnotherTypeIsAChild() {
        let tabs = """
            enum Tab {
                case home
                @ViewBuilder
                func makeContent() -> some View {
                    switch self {
                    case .home: Leaf()
                    }
                }
                func title() -> String { "Home" }
            }
            """
        let root = """
            struct Root: View {
                let tabs: [Tab] = [.home]
                var body: some View { ForEach(tabs) { tab in content(for: tab) } }
                func content(for tab: Tab) -> some View { tab.makeContent() }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Root()"), "Tabs.swift": tabs, "Root.swift": root,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Root` is shown from App `MyApp` without `Cart`; "
                    + "required by Root → Root.content(for:) → Tab.makeContent() → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func methodsThatDoNotBuildViewsAreNotNodes() {
        let tabs = """
            enum Tab {
                @ViewBuilder func makeContent() -> some View { Text("x") }
                func title() -> String { "Home" }
            }
            """
        let summary = Summarizer.summarize(path: "Tabs.swift", source: tabs)
        #expect(
            summary.nodes.map(\.name) == [
                .member(owner: TypeName(path: "Tab"), name: MemberName(base: "makeContent", labels: .called([])))
            ]
        )
    }

    @Test
    func overloadsAreSeparateHelpers() {
        let screen = """
            struct Screen: View {
                var body: some View { row(for: 1) }
                func row(for id: Int) -> some View { Text("x") }
                func row(named: String) -> some View { Leaf() }
            }
            """
        let named = screen.replacingOccurrences(of: "row(for: 1) }", with: "row(named: \"x\") }")
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Screen.swift": screen, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == []
        )
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Screen.swift": named, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; "
                    + "required by Screen → Screen.row(named:) → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test(arguments: [
        "struct Screen: View { let tab: any TabItem; var body: some View { tab.makeView() } }",
        "struct Screen: View { let tabs: [any TabItem]; var body: some View { ForEach(tabs) { tab in tab.makeView() } } }",
    ])
    func protocolMembersDispatchToConformers(screen: String) {
        let tabs = """
            protocol TabItem { func makeView() -> AnyView }
            struct Posts { func makeView() -> AnyView { AnyView(Leaf()) } }
            extension Posts: @MainActor TabItem {}
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Screen(tab: Posts())"), "Tabs.swift": tabs, "Screen.swift": screen,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; "
                    + "required by Screen → Posts.makeView() → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func selfMeansTheEnclosingType() {
        let screen = """
            struct Screen: View {
                var body: some View { Self.badge(for: 1) }
                private static func badge(for count: Int) -> some View { Leaf() }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Screen.swift": screen, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; "
                    + "required by Screen → Screen.badge(for:) → Leaf (Leaf.swift:2)."
            ]
        )
    }
}
