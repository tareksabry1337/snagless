import Testing

@Suite
struct NavigationDestinationTests {
    struct Layout: CustomTestStringConvertible, Sendable {
        let name: String
        let root: String
        let declarer: String
        let crashes: Bool

        var testDescription: String { name }
    }

    static let destination = "Text(\"x\").navigationDestination(for: Int.self) { _ in Leaf() }"

    static let layouts = [
        Layout(
            name: "provided on the stack",
            root: "NavigationStack { Declarer() }.environment(Cart.shared)",
            declarer: destination,
            crashes: false,
        ),
        Layout(
            name: "provided between the stack and the declaring view",
            root: "NavigationStack { Declarer().environment(Cart.shared) }",
            declarer: destination,
            crashes: true,
        ),
        Layout(
            name: "provided on the declaring view after the modifier",
            root: "NavigationStack { Declarer() }",
            declarer: destination + ".environment(Cart.shared)",
            crashes: true,
        ),
        Layout(
            name: "provided inside the destination",
            root: "NavigationStack { Declarer() }",
            declarer:
                "Text(\"x\").navigationDestination(isPresented: .constant(true)) { Leaf().environment(Cart.shared) }",
            crashes: false,
        ),
        Layout(
            name: "stack and destination in one body, provided on the stack",
            root: "NavigationStack { \(destination) }.environment(Cart.shared)",
            declarer: "Text(\"unused\")",
            crashes: false,
        ),
        Layout(
            name: "stack and destination in one body, provided between",
            root: "NavigationStack { \(destination).environment(Cart.shared) }",
            declarer: "Text(\"unused\")",
            crashes: true,
        ),
    ]

    @Test(arguments: layouts)
    func destinationGetsTheEnvironmentOfItsStack(layout: Layout) {
        let errors = TestProject([
            "App.swift": Fixture.app(showing: "Root()"),
            "Root.swift": "struct Root: View { var body: some View { \(layout.root) } }",
            "Declarer.swift": "struct Declarer: View { var body: some View { \(layout.declarer) } }",
            "Leaf.swift": Fixture.leafView,
            "Cart.swift": Fixture.cart,
        ])
        .errors()
        #expect(errors.count == (layout.crashes ? 1 : 0))
        #expect(errors.allSatisfy { $0.hasSuffix(Self.destinationNote) })
    }

    @Test
    func witnessNamesTheDeclaringViewAndExplainsTheStack() {
        let errors = TestProject([
            "App.swift": Fixture.app(showing: "Root()"),
            "Root.swift":
                "struct Root: View { var body: some View { NavigationStack { Declarer().environment(Cart.shared) } } }",
            "Declarer.swift": "struct Declarer: View { var body: some View { \(Self.destination) } }",
            "Leaf.swift": Fixture.leafView,
            "Cart.swift": Fixture.cart,
        ])
        .errors()
        #expect(
            errors == [
                "App.swift:1:64: error: `Root` is shown from App `MyApp` without `Cart`; required by Root → Declarer → Leaf"
                    + " (Leaf.swift:2)." + Self.destinationNote
            ]
        )
    }

    @Test
    func destinationWithoutAVisibleStackIsCheckedAgainstTheRoot() {
        let middle = "struct Middle: View { var body: some View { Declarer().environment(Cart.shared) } }"
        let declarer = "struct Declarer: View { var body: some View { \(Self.destination) } }"
        let base = [
            "Middle.swift": middle, "Declarer.swift": declarer, "Leaf.swift": Fixture.leafView,
            "Cart.swift": Fixture.cart,
        ]
        let providedAtTheRoot = TestProject(
            base.merging(["App.swift": Fixture.app(showing: "Middle().environment(Cart.shared)")]) { $1 }
        )
        let providedInBetween = TestProject(base.merging(["App.swift": Fixture.app(showing: "Middle()")]) { $1 })
        #expect(providedAtTheRoot.errors() == [])
        #expect(providedInBetween.errors().count == 1)
    }

    static let destinationNote =
        " A navigationDestination gets the environment of its NavigationStack;"
        + " provide the value on the stack or inside the destination."
}
