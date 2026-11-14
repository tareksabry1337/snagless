import Testing

@Suite
struct MemberChainTests {
    @Test
    func memberChainsResolveThroughDeclaredMemberTypes() {
        let manager = """
            final class AccountManager {
                static let shared = AccountManager()
                var currentCart: Cart
                func makeStore(for id: Int) -> Store { Store() }
            }
            """
        let leaf = """
            struct Leaf: View {
                @Environment(Cart.self) private var cart
                @Environment(Store.self) private var store
                var body: some View { Text("leaf") }
            }
            """
        let app = """
            @main struct MyApp: App {
                let manager = AccountManager.shared
                var body: some Scene {
                    WindowGroup {
                        Leaf()
                            .environment(manager.currentCart)
                            .environment(AccountManager.shared.makeStore(for: 1))
                    }
                }
            }
            """
        let sources = ["App.swift": app, "Manager.swift": manager, "Leaf.swift": leaf]
        #expect(TestProject(sources).errors() == [])
        #expect(TestProject(sources).notes == [])
    }

    @Test
    func staticMembersResolveToTheirDeclaredType() {
        let sources = [
            "App.swift": Fixture.app(showing: "Leaf().environment(Services.cart)"),
            "Services.swift": "enum Services { static let cart = Cart() }",
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
        #expect(TestProject(sources).notes == [])
    }

    @Test
    func unknownMemberChainIsReportedAsUnresolved() {
        let app = """
            @main struct MyApp: App {
                let manager = AccountManager()
                var body: some Scene { WindowGroup { Leaf().environment(manager.somethingElse) } }
            }
            """
        let sources = ["App.swift": app, "Leaf.swift": Fixture.leafView]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:3:42: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ]
        )
        #expect(
            TestProject(sources).notes == [
                "App.swift:3:61: note: unresolved injection `environment(manager.somethingElse)`; "
                    + "add `// snagless: provides Type` if it provides a checked type"
            ]
        )
    }

    @Test
    func undeclaredStaticMemberIsUnresolvedRatherThanAssumedToReturnItsType() {
        let sources = [
            "App.swift": Fixture.app(showing: "Leaf().environment(Cart.shared)"), "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [Fixture.leafMissingCartFromApp])
        #expect(
            TestProject(sources).notes == [
                "App.swift:1:83: note: unresolved injection `environment(Cart.shared)`; "
                    + "add `// snagless: provides Type` if it provides a checked type"
            ]
        )
    }

    @Test
    func genericParametersAreNotDeclaredTypes() {
        let app = """
            @main struct MyApp: App {
                let factory = Factory()
                var body: some Scene { WindowGroup { Leaf().environment(factory.make()) } }
            }
            """
        let factory = "final class Factory { func make<Cart>() -> Cart { fatalError() } }"
        #expect(
            TestProject(["Factory.swift": factory, "App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [
                "App.swift:3:42: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ]
        )
    }
}
