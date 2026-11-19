import Testing

@Suite
struct NavigationDestinationTests {
    struct Layout: CustomTestStringConvertible, Sendable {
        let name: String
        let root: String
        let declarer: String
        let crashPath: String?

        var testDescription: String { name }
    }

    static let destination = "Text(\"x\").navigationDestination(for: Int.self) { _ in Leaf() }"

    static let layouts = [
        Layout(
            name: "provided on the stack",
            root: "NavigationStack { Declarer() }.environment(Cart.shared)",
            declarer: destination,
            crashPath: nil,
        ),
        Layout(
            name: "provided between the stack and the declaring view",
            root: "NavigationStack { Declarer().environment(Cart.shared) }",
            declarer: destination,
            crashPath: "Root → Declarer → navigationDestination → Leaf",
        ),
        Layout(
            name: "provided on the declaring view after the modifier",
            root: "NavigationStack { Declarer() }",
            declarer: destination + ".environment(Cart.shared)",
            crashPath: "Root → Declarer → navigationDestination → Leaf",
        ),
        Layout(
            name: "provided inside the destination",
            root: "NavigationStack { Declarer() }",
            declarer:
                "Text(\"x\").navigationDestination(isPresented: .constant(true)) { Leaf().environment(Cart.shared) }",
            crashPath: nil,
        ),
        Layout(
            name: "stack and destination in one body, provided on the stack",
            root: "NavigationStack { \(destination) }.environment(Cart.shared)",
            declarer: "Text(\"unused\")",
            crashPath: nil,
        ),
        Layout(
            name: "stack and destination in one body, provided between",
            root: "NavigationStack { \(destination).environment(Cart.shared) }",
            declarer: "Text(\"unused\")",
            crashPath: "Root → navigationDestination → Leaf",
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
        #expect(errors == layout.crashPath.map { [Self.missingCart(path: $0)] } ?? [])
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
        #expect(
            providedInBetween.errors() == [Self.missingCart(path: "Middle → Declarer → navigationDestination → Leaf")]
        )
    }

    @Test(arguments: [
        "NavigationView { Declarer() }.environment(Cart.shared)",
        "NavigationView { Declarer().environment(Cart.shared) }",
        "NavigationView { Declarer() }",
    ])
    func destinationInsideANavigationViewIsCheckedAgainstTheRoot(root: String) {
        let errors = TestProject([
            "App.swift": Fixture.app(showing: "Root()"),
            "Root.swift": "struct Root: View { var body: some View { \(root) } }",
            "Declarer.swift": "struct Declarer: View { var body: some View { \(Self.destination) } }",
            "Leaf.swift": Fixture.leafView,
            "Cart.swift": Fixture.cart,
        ])
        .errors()
        #expect(errors == [Self.missingCart(path: "Root → Declarer → navigationDestination → Leaf")])
    }

    private static func missingCart(path: String) -> String {
        "App.swift:1:64: error: `Leaf` needs `Cart`: App `MyApp` → \(path) (Leaf.swift:2)"
    }
}
