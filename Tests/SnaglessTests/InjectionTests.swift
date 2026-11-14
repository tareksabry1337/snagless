import Testing

@Suite
struct InjectionTests {
    @Test
    func optionalEnvironmentIsNotARequirement() {
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart: Cart?
                var body: some View { Text("leaf") }
            }
            """
        #expect(TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf]).errors() == [])
    }

    @Test
    func environmentObjectIsARequirement() {
        let leaf = """
            struct Leaf: View {
                @EnvironmentObject var store: Store
                var body: some View { Text("leaf") }
            }
            """
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf]).errors() == [
                "App.swift:1:64: error: `Leaf` is shown from App `MyApp` without `Store`; required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func requirementInsideConditionalCompilationIsARequirement() {
        let leaf = """
            struct Leaf: View {
                #if os(macOS)
                @Environment(Window.self) private var window
                #else
                @EnvironmentObject var store: Store
                #endif
                var body: some View { Text("leaf") }
            }
            """
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Leaf()"), "Leaf.swift": leaf]).errors() == [
                "App.swift:1:64: error: `Leaf` is shown from App `MyApp` without `Store`; required by Leaf (Leaf.swift:5).",
                "App.swift:1:64: error: `Leaf` is shown from App `MyApp` without `Window`; required by Leaf (Leaf.swift:3).",
            ]
        )
    }

    @Test
    func helperInsideConditionalCompilationIsFollowed() {
        let parent = """
            struct Parent: View {
                var body: some View { content }
                #if os(iOS)
                var content: some View { Leaf() }
                #endif
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Parent()"), "Parent.swift": parent, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Parent` is shown from App `MyApp` without `Cart`; required by Parent → Parent.content → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func modifierInsideDoesNotReachASheetOutside() {
        let parent = """
            struct Parent: View {
                @State private var shown = false
                var body: some View {
                    Text("x")
                        .environment(Cart.shared)
                        .sheet(isPresented: $shown) { Leaf() }
                }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Parent()"), "Parent.swift": parent, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Parent` is shown from App `MyApp` without `Cart`; required by Parent → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func injectionOutsideASheetReachesItsContent() {
        let parent = """
            struct Parent: View {
                @State private var shown = false
                var body: some View {
                    Text("x")
                        .sheet(isPresented: $shown) { Leaf() }
                        .environment(Cart.preview())
                }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Parent()"), "Parent.swift": parent, "Leaf.swift": Fixture.leafView,
                "Cart.swift": Fixture.cart,
            ])
            .errors() == []
        )
    }

    @Test
    func extensionsAndModifiersProvideThroughEachOther() {
        let support = """
            extension View {
                func withCart() -> some View { environment(Cart.shared) }
                func withEverything() -> some View { withCart().modifier(InjectStore()) }
            }
            struct InjectStore: ViewModifier {
                func body(content: Content) -> some View { content.environmentObject(Store()) }
            }
            """
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart
                @EnvironmentObject var store: Store
                var body: some View { Text("leaf") }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Leaf().withEverything()"), "Support.swift": support, "Leaf.swift": leaf,
            "Cart.swift": Fixture.cart,
        ]
        #expect(TestProject(sources).errors() == [])
    }

    @Test
    func providerCountsOnlyInjectionsOnItsOwnContent() {
        let support = """
            extension View {
                func withSheet() -> some View {
                    sheet(isPresented: .constant(true)) { Text("x").environment(Cart()) }
                }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Leaf().withSheet()"), "Support.swift": support,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [Fixture.leafMissingCartFromApp])
    }

    @Test
    func injectionInsidePostfixIfConfigReachesTheBase() {
        let screen = """
            struct Screen: View {
                var body: some View {
                    Leaf()
                    #if os(iOS)
                        .environment(Cart())
                    #endif
                }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Screen.swift": screen, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == []
        )
    }

    @Test
    func closureParameterShadowsAProperty() {
        let screen = """
            struct Screen: View {
                @State private var cart = Cart()
                let items = [1]
                var body: some View { ForEach(items) { cart in Leaf().environment(cart) } }
            }
            """
        #expect(
            TestProject([
                "App.swift": Fixture.app(showing: "Screen()"), "Screen.swift": screen, "Leaf.swift": Fixture.leafView,
            ])
            .errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; required by Screen → Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func wrapperThatInjectsIntoItsContentCoversIt() {
        let wrapper = """
            struct Injecting<Content: View>: View {
                var content: () -> Content
                init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
                var body: some View { content().environment(Cart()) }
            }
            """
        let screen = "struct Screen: View { var body: some View { Injecting { Leaf() } } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Screen()"), "Wrapper.swift": wrapper, "Screen.swift": screen,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
    }

    @Test
    func wrapperThatInjectsAroundAStackCoversItsContent() {
        let wrapper = """
            struct Stacked<Content: View>: View {
                @ViewBuilder var content: () -> Content
                @State private var cart = Cart()
                var body: some View { NavigationStack { content().padding() }.environment(cart) }
            }
            """
        let screen = "struct Screen: View { var body: some View { Stacked { Leaf() } } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Screen()"), "Wrapper.swift": wrapper, "Screen.swift": screen,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
    }

    @Test
    func wrapperThatInjectsIntoOneSlotDoesNotCoverTheOther() {
        let wrapper = """
            struct HalfInjecting<Content: View>: View {
                let primary: Content
                let secondary: Content
                var body: some View { VStack { primary.environment(Cart()); secondary } }
            }
            """
        let screen = "struct Screen: View { var body: some View { HalfInjecting(primary: Leaf(), secondary: Leaf()) } }"
        let sources = [
            "App.swift": Fixture.app(showing: "Screen()"), "Wrapper.swift": wrapper, "Screen.swift": screen,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:1:64: error: `Screen` is shown from App `MyApp` without `Cart`; required by Screen → Leaf (Leaf.swift:2)."
            ]
        )
    }
}
