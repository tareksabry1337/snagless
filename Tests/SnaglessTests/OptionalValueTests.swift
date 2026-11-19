import Testing

@Suite
struct OptionalValueTests {
    private static let store = """
        final class Store {
            var cart: Cart?
            var wallet: Wallet?
            let basket = Cart()
            func makeCart() -> Cart { Cart() }
        }
        final class Wallet {
            let cart = Cart()
        }
        """

    @Test(arguments: [
        ("cart", "@State private var cart: Cart?"),
        ("cart", "private var cart: Cart!"),
        ("cart", "private var cart: Optional<Cart> = nil"),
        ("self.cart", "@State private var cart: Cart?"),
        ("makeCart()", "func makeCart() -> Cart? { nil }"),
        ("store.cart", "let store = Store()"),
        ("store?.cart", "let store: Store? = nil"),
        ("store.wallet?.cart", "let store = Store()"),
        ("store?.wallet!.cart", "let store: Store? = nil"),
    ])
    func optionalValueStaysUnresolved(expression: String, members: String) {
        InjectedValueTests.expectUnresolved(
            TestProject([
                "App.swift": InjectedValueTests.app(injecting: expression, members: members),
                "Store.swift": Self.store,
                "Leaf.swift": Fixture.leafView,
            ]),
            expression,
        )
    }

    @Test(arguments: [
        ("cart!", "@State private var cart: Cart?"),
        ("store.cart!", "let store = Store()"),
        ("store.wallet!.cart", "let store = Store()"),
        ("store.basket", "var store: Store!"),
        ("store.makeCart()", "var store: Store!"),
    ])
    func forceUnwrappedValueResolves(expression: String, members: String) {
        InjectedValueTests.expectResolved(
            TestProject([
                "App.swift": InjectedValueTests.app(injecting: expression, members: members),
                "Store.swift": Self.store,
                "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    @Test(arguments: [
        "if let cart { Leaf().environment(cart) }",
        "if let current = cart { Leaf().environment(current) }",
        "if let cart = store.cart { Leaf().environment(cart) }",
    ])
    func optionalValueUnwrappedByIfLetResolves(content: String) {
        let app = """
            @main struct MyApp: App {
                @State private var cart: Cart?
                let store = Store()
                var body: some Scene { WindowGroup { \(content) } }
            }
            """
        InjectedValueTests.expectResolved(
            TestProject(["App.swift": app, "Store.swift": Self.store, "Leaf.swift": Fixture.leafView])
        )
    }

    @Test(arguments: ["guard let cart else", "guard let cart = cart else"])
    func optionalValueUnwrappedByGuardLetResolves(guardCondition: String) {
        let app = """
            @main struct MyApp: App {
                @State private var cart: Cart?
                var body: some Scene { WindowGroup { content } }
                var content: AnyView {
                    \(guardCondition) { return AnyView(Text("x")) }
                    return AnyView(Leaf().environment(cart))
                }
            }
            """
        InjectedValueTests.expectResolved(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]))
    }

    @Test
    func unwrappedTopLevelFunctionReturningAnOptionalStaysUnresolved() {
        InjectedValueTests.expectUnresolved(
            TestProject([
                "App.swift": InjectedValueTests.app(injecting: "makeCart()!"),
                "MakeCart.swift": "func makeCart() -> Cart? { Cart() }",
                "Leaf.swift": Fixture.leafView,
            ]),
            "makeCart()!",
        )
    }

    @Test
    func providesCommentCoversAnOptionalValue() {
        let app = """
            @main struct MyApp: App {
                @State private var cart: Cart?
                var body: some Scene {
                    WindowGroup {
                        Leaf()
                            .environment(cart) // snagless: provides Cart
                    }
                }
            }
            """
        InjectedValueTests.expectResolved(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]))
    }
}
