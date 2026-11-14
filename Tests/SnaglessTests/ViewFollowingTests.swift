import Testing

@Suite
struct ViewFollowingTests {
    @Test
    func witnessNamesEveryHop() {
        let tabs = "struct Tabs: View { var body: some View { TabView { Leaf() } } }"
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Tabs()"), "Tabs.swift": tabs, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Tabs` is shown from App `MyApp` without `Cart`; required by Tabs → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test(arguments: [
        (
            "Screens.leaf()",
            [
                "App.swift:1:72: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ],
        ),
        ("Screens.leaf().environment(Cart.shared)", []),
        (
            "Rows().leaf()",
            [
                "App.swift:1:71: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ],
        ),
    ])
    func callReturningAConcreteViewShowsThatView(content: String, expected: [String]) {
        let factories = """
            enum Screens {
                static func leaf() -> Leaf { Leaf() }
            }
            struct Rows {
                func leaf() -> Leaf { Leaf() }
            }
            """
        let project = TestProject([
            "App.swift": Fixture.app(showing: content), "Factories.swift": factories, "Leaf.swift": Fixture.leafView,
            "Cart.swift": Fixture.cart,
        ])
        #expect(project.errors() == expected)
    }

    @Test
    func witnessIsTheShortestPath() {
        let views = """
            struct Root: View { var body: some View { VStack { A1(); Leaf() } } }
            struct A1: View { var body: some View { A2() } }
            struct A2: View { var body: some View { Leaf() } }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Root()"), "Views.swift": views, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Root` is shown from App `MyApp` without `Cart`; required by Root → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func modifierInsidePostfixIfConfigIsFollowed() {
        let support = """
            extension View {
                func withPopover() -> some View { modifier(Popover()) }
            }
            struct Popover: ViewModifier {
                func body(content: Content) -> some View { content.overlay { Leaf() } }
            }
            """
        let row = """
            struct Row: View {
                var body: some View {
                    Text("x")
                    #if os(macOS)
                        .withPopover()
                    #endif
                }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Row()"), "Support.swift": support, "Row.swift": row,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Row` is shown from App `MyApp` without `Cart`; "
                    + "required by Row → .withPopover() → Popover → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func projectModifierNamedLikeABuiltInOneIsFollowed() {
        let support = "extension View { func padding(_ amount: Int) -> some View { overlay { Leaf() } } }"
        let row = "struct Row: View { var body: some View { Text(\"x\").padding(4) } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Row()"), "Support.swift": support, "Row.swift": row,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Row` is shown from App `MyApp` without `Cart`; "
                    + "required by Row → .padding() → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func toolbarContentIsFollowedLikeAView() {
        let toolbar = """
            struct Items: ToolbarContent {
                var body: some ToolbarContent { ToolbarItem { menu } }
                private var menu: some View { Leaf() }
            }
            """
        let screen = "struct Screen: View { var body: some View { Text(\"x\").toolbar { Items() } } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Screen()"), "Toolbar.swift": toolbar, "Screen.swift": screen,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; "
                    + "required by Screen → Items → Items.menu → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func initializerReferenceIsAnEdge() {
        let rows = """
            struct Rows: View {
                let items = [1, 2]
                var body: some View { ForEach(items, id: \\.self, content: Leaf.init) }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Rows()"), "Rows.swift": rows, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Rows` is shown from App `MyApp` without `Cart`; required by Rows → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func modelMethodIsNotAViewExtension() {
        let support = """
            extension View { func load() -> some View { overlay { Leaf() } } }
            final class Model { func load() {} }
            struct Screen: View {
                let model = Model()
                var body: some View { Text("x").task { model.load() } }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Support.swift": support, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == []
        )
    }
}
