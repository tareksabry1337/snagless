import Testing

@Suite
struct InjectedValueTests {
    private static let missingCart =
        "error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."

    private static func app(injecting expression: String, members: String = "") -> String {
        """
        @main struct MyApp: App {
            \(members)
            var body: some Scene { WindowGroup { Leaf().environment(\(expression)) } }
        }
        """
    }

    private static func unresolvedNote(_ expression: String) -> String {
        "App.swift:3:61: note: unresolved injection `environment(\(expression))`; "
            + "add `// snagless: provides Type` if it provides a checked type"
    }

    private static func expectResolved(_ project: TestProject) {
        #expect(project.errors() == [])
        #expect(project.notes == [])
    }

    private static func expectUnresolved(_ project: TestProject, _ expression: String) {
        #expect(project.errors() == ["App.swift:3:42: " + missingCart])
        #expect(project.notes == [unresolvedNote(expression)])
    }

    @Test(arguments: ["makeCart()", "self.makeCart()"])
    func callToAMethodOfTheEnclosingTypeResolves(expression: String) {
        let app = Self.app(injecting: expression, members: "func makeCart() -> Cart { Cart() }")
        Self.expectResolved(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]))
    }

    @Test(arguments: ["makeCart()", "self.makeCart()"])
    func callToAMethodInAnExtensionInAnotherFileResolves(expression: String) {
        Self.expectResolved(
            TestProject([
                "App.swift": Self.app(injecting: expression),
                "App+Factory.swift": "extension MyApp { func makeCart() -> Cart { Cart() } }",
                "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    @Test
    func callToATopLevelFunctionInTheSameModuleResolves() {
        Self.expectResolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()"),
                "Factory.swift": "func makeCart() -> Cart { Cart() }",
                "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    @Test
    func explicitSelfDoesNotReachATopLevelFunction() {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: "self.makeCart()"),
                "Factory.swift": "func makeCart() -> Cart { Cart() }",
                "Leaf.swift": Fixture.leafView,
            ]),
            "self.makeCart()",
        )
    }

    @Test
    func topLevelFunctionInAnImportedModuleResolves() {
        Self.expectResolved(
            TestProject(modules: [
                "Shop": ["Shop/Factory.swift": "public func makeCart() -> Cart { Cart() }"],
                "App": [
                    "App.swift": "import Shop\n" + Self.app(injecting: "makeCart()"), "Leaf.swift": Fixture.leafView,
                ],
            ])
        )
    }

    @Test
    func topLevelFunctionInAModuleThatIsNotImportedStaysUnresolved() {
        Self.expectUnresolved(
            TestProject(modules: [
                "Shop": ["Shop/Factory.swift": "public func makeCart() -> Cart { Cart() }"],
                "App": ["App.swift": Self.app(injecting: "makeCart()"), "Leaf.swift": Fixture.leafView],
            ]),
            "makeCart()",
        )
    }

    @Test
    func methodOnTheEnclosingTypeWinsOverATopLevelFunction() {
        let wallet = TestProject([
            "App.swift": Self.app(injecting: "makeCart()", members: "func makeCart() -> Wallet { Wallet() }"),
            "Factory.swift": "func makeCart() -> Cart { Cart() }",
            "Leaf.swift": Fixture.leafView,
        ])
        #expect(wallet.errors() == ["App.swift:3:42: " + Self.missingCart])
        #expect(wallet.notes == [])
        Self.expectResolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()", members: "func makeCart() -> Cart { Cart() }"),
                "Factory.swift": "func makeCart() -> Wallet { Wallet() }",
                "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    @Test(arguments: [
        "func makeCart() -> Cart { Cart() }\nfunc makeCart(id: Int) -> Wallet { Wallet() }",
        "extension MyApp {\nfunc makeCart() -> Cart { Cart() }\nfunc makeCart(id: Int) -> Wallet { Wallet() }\n}",
    ])
    func overloadsWithDifferentReturnTypesStayUnresolved(factory: String) {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()"),
                "Factory.swift": factory,
                "Leaf.swift": Fixture.leafView,
            ]),
            "makeCart()",
        )
    }

    @Test
    func overloadsSplitAcrossExtensionsStayUnresolved() {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()", members: "func makeCart() -> Cart { Cart() }"),
                "Factory.swift": "extension MyApp { func makeCart(id: Int) -> Wallet { Wallet() } }",
                "Leaf.swift": Fixture.leafView,
            ]),
            "makeCart()",
        )
    }

    @Test(arguments: ["some Cart", "any Cart"])
    func opaqueAndExistentialReturnTypesStayUnresolved(returnType: String) {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()", members: "func makeCart() -> \(returnType) { Cart() }"),
                "Leaf.swift": Fixture.leafView,
            ]),
            "makeCart()",
        )
    }

    @Test
    func methodFromAProtocolExtensionStaysUnresolved() {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: "makeCart()"),
                "Factory.swift":
                    "protocol Factory {}\nextension Factory { func makeCart() -> Cart { Cart() } }\nextension MyApp: Factory {}",
                "Leaf.swift": Fixture.leafView,
            ]),
            "makeCart()",
        )
    }

    @Test(arguments: ["makeStore().cart", "self.makeStore().cart"])
    func memberOfAFactoryResultResolves(expression: String) {
        Self.expectResolved(
            TestProject([
                "App.swift": Self.app(injecting: expression, members: "func makeStore() -> Store { Store() }"),
                "Store.swift": "final class Store { let cart: Cart = Cart() }",
                "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    private static let twoCarts = "let first = Cart(); let second = Cart(); let wallet = Wallet(); let flag = true"

    @Test(arguments: ["flag ? first : second", "(flag ? first : second)", "MiniCart() as Cart"])
    func expressionWithOneStaticTypeResolves(expression: String) {
        Self.expectResolved(
            TestProject([
                "App.swift": Self.app(injecting: expression, members: Self.twoCarts), "Leaf.swift": Fixture.leafView,
            ])
        )
    }

    @Test(arguments: ["flag ? first : wallet", "MiniCart() as? Cart"])
    func expressionWithoutOneStaticTypeStaysUnresolved(expression: String) {
        Self.expectUnresolved(
            TestProject([
                "App.swift": Self.app(injecting: expression, members: Self.twoCarts), "Leaf.swift": Fixture.leafView,
            ]),
            expression,
        )
    }
}
