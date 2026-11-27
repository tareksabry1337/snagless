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
                "App.swift:3:42: error: `Leaf` needs `Cart`: App `MyApp` → Leaf (Leaf.swift:2)"
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
                "App.swift:3:42: error: `Leaf` needs `Cart`: App `MyApp` → Leaf (Leaf.swift:2)"
            ]
        )
    }

    @Test
    func extensionsInAnotherFileSeeMembersDeclaredInTheType() {
        let app = """
            @main struct MyApp: App {
                private let cart = Cart()
                var body: some Scene { WindowGroup { content } }
            }
            """
        let content = """
            extension MyApp {
                var content: some View { VStack { Leaf().environment(self.cart); Leaf().environment(cart) } }
            }
            """
        let sources = ["App.swift": app, "Content.swift": content, "Leaf.swift": Fixture.leafView]
        #expect(TestProject(sources).errors() == [])
        #expect(TestProject(sources).notes == [])
    }

    @Test
    func membersDefinedByAChainResolveFromOtherTypes() {
        let app = """
            @main struct MyApp: App {
                let session = Session()
                var body: some Scene { WindowGroup { Leaf().environment(session.manager.cart) } }
            }
            """
        let sources = [
            "App.swift": app,
            "Session.swift": "final class Session { let manager = AccountManager.shared }",
            "Manager.swift": "final class AccountManager { static let shared = AccountManager(); let cart = Cart() }",
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
        #expect(TestProject(sources).notes == [])
    }

    @Test
    func membersDefinedThroughEachOtherStayUnresolved() {
        let app = """
            @main struct MyApp: App {
                lazy var first = second
                lazy var second = first
                var body: some Scene { WindowGroup { Leaf().environment(first) } }
            }
            """
        let sources = ["App.swift": app, "Leaf.swift": Fixture.leafView]
        #expect(
            TestProject(sources).errors() == [
                "App.swift:4:42: error: `Leaf` needs `Cart`: App `MyApp` → Leaf (Leaf.swift:2)"
            ]
        )
    }

    @Test
    func ternaryResolvesWhenBothBranchesHaveTheSameType() {
        let app = """
            @main struct MyApp: App {
                let live = Cart()
                let preview = Cart.preview()
                let isPreview = false
                var body: some Scene { WindowGroup { Leaf().environment(isPreview ? preview : live) } }
            }
            """
        let sources = ["App.swift": app, "Cart.swift": Fixture.cart, "Leaf.swift": Fixture.leafView]
        #expect(TestProject(sources).errors() == [])
        #expect(TestProject(sources).notes == [])
    }
}
