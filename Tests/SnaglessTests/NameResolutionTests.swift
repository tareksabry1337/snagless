import SnaglessAnalysis
import Testing

@Suite
struct NameResolutionTests {
    @Test
    func sameNamedViewsInOtherModulesStaySeparate() {
        let other = """
            struct Detail: View {
                @Environment(Cart.self) private var cart
                var body: some View { Text("x") }
            }
            """
        let mine = "struct Detail: View { var body: some View { Text(\"y\") } }"
        #expect(
            TestProject(modules: [
                "Other": ["Other/Detail.swift": other],
                "App": ["App/Detail.swift": mine, "App/App.swift": Fixture.app(showing: "Detail()")],
            ])
            .errors() == [
                "Other/Detail.swift:2:41: warning: `Detail` is unreachable from every App, preview and hosting root"
            ]
        )
    }

    @Test
    func nestedTypesWithTheSameNameStaySeparate() {
        let parents = """
            struct ParentA: View {
                var body: some View { Row() }
                struct Row: View { var body: some View { header } }
            }
            struct ParentB: View {
                var body: some View { Row() }
                struct Row: View { var body: some View { Text("b") } }
            }
            """
        let header = "extension ParentA.Row { var header: some View { Leaf() } }"
        let sources = ["Parents.swift": parents, "Header.swift": header, "Leaf.swift": Fixture.leafView]
        let provided = Fixture.app(showing: "VStack { ParentA().environment(Cart()); ParentB() }")
        #expect(TestProject(sources.merging(["App.swift": provided]) { $1 }).errors() == [])
        #expect(
            TestProject(sources.merging(["App.swift": Fixture.app(showing: "ParentA()")]) { $1 }).errors() == [
                "App.swift:1:64: error: `Leaf` needs `Cart`: "
                    + "App `MyApp` → ParentA → ParentA.Row → ParentA.Row.header → Leaf (Leaf.swift:2)"
            ]
        )
    }

    @Test(arguments: [
        (
            "Panel().environment(Bank.Store())",
            [
                "App.swift:1:64: error: `Panel` needs `Shop.Store`: App `MyApp` → Panel (Panel.swift:1)"
            ],
        ),
        ("Panel().environment(Shop.Store())", []),
        ("Shop.Shell()", []),
    ])
    func nestedEnvironmentTypesWithTheSameNameStaySeparate(content: String, expected: [String]) {
        let stores = """
            enum Shop { @Observable final class Store {} }
            enum Bank { @Observable final class Store {} }
            extension Shop {
                struct Shell: View { var body: some View { Panel().environment(Store()) } }
            }
            """
        let panel =
            "struct Panel: View { @Environment(Shop.Store.self) private var store; var body: some View { Text(\"p\") } }"
        let sources = ["Stores.swift": stores, "Panel.swift": panel, "App.swift": Fixture.app(showing: content)]
        #expect(TestProject(sources).errors() == expected)
    }

    @Test(arguments: [
        ("Outer.Screen()", [Fixture.leafUnchecked]),
        (
            "Outer.Extended()",
            [
                "App.swift:1:64: error: `Leaf` needs `Cart`: "
                    + "App `MyApp` → Outer.Extended → Outer.Extended.extra → Leaf (Leaf.swift:2)"
            ],
        ),
    ])
    func extensionsOfNestedTypesSeeOnlyTheirOwnMembers(content: String, expected: [String]) {
        let types = """
            struct Outer {
                struct Leaf: View { var body: some View { Text("inner") } }
                struct Screen: View { var body: some View { Leaf() } }
                struct Extended: View { var body: some View { extra } }
            }
            extension Outer.Extended { var extra: some View { Leaf() } }
            """
        let sources = [
            "Types.swift": types, "Leaf.swift": Fixture.leafView, "App.swift": Fixture.app(showing: content),
        ]
        #expect(TestProject(sources).errors() == expected)
    }

    @Test
    func moduleQualifiedNamesResolveToTheirDeclaration() {
        let shop = """
            @Observable final class Cart {}
            struct Basket: View { @Environment(Shop.Cart.self) private var cart; var body: some View { Text("b") } }
            """
        let app = "import Shop\n" + Fixture.app(showing: "Shop.Basket().environment(Cart())")
        let project = TestProject(modules: ["Shop": ["Shop/Shop.swift": shop], "App": ["App/App.swift": app]])
        let analysis = Analysis(project.files, options: AnalysisOptions())
        #expect(analysis.diagnostics == [])
        #expect(analysis.stats.reachableViews == 1)
    }

    @Test(arguments: [
        (
            "Badge()",
            ["Shop/Shop.swift:2:65: warning: `Badge` is unreachable from every App, preview and hosting root"],
        ),
        (
            "Shop.Badge()",
            [
                "App/App.swift:2:64: error: `Badge` needs `Cart`: App `MyApp` → Badge (Shop/Shop.swift:2)"
            ],
        ),
    ])
    func moduleQualifiedNamesPickThatModule(content: String, expected: [String]) {
        let shop = """
            @Observable public final class Cart {}
            public struct Badge: View { @Environment(Cart.self) private var cart; public var body: some View { Text("s") } }
            """
        let mine = "struct Badge: View { var body: some View { Text(\"m\") } }"
        #expect(
            TestProject(modules: [
                "Shop": ["Shop/Shop.swift": shop],
                "App": ["App/Badge.swift": mine, "App/App.swift": "import Shop\n" + Fixture.app(showing: content)],
            ])
            .errors() == expected
        )
    }

    @Test
    func extensionsOfModuleQualifiedTypesSeeTheirNestedTypes() {
        let shop = """
            final class Cart {
                struct Row: View { @Environment(Wallet.self) private var wallet; var body: some View { Text("r") } }
            }
            """
        let app = """
            import Shop
            extension Shop.Cart { var badge: some View { Row() } }
            \(Fixture.app(showing: "Shop.Cart().badge"))
            """
        #expect(
            TestProject(modules: ["Shop": ["Shop/Shop.swift": shop], "App": ["App/App.swift": app]]).errors() == [
                "App/App.swift:3:76: error: `Cart.Row` needs `Wallet`: "
                    + "App `MyApp` → Cart.badge → Cart.Row (Shop/Shop.swift:2)"
            ]
        )
    }
}
