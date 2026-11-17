import Foundation

enum Fixture {
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let leafView = """
        struct Leaf: View {
            @Environment(Cart.self) private var cart
            var body: some View { Text("leaf") }
        }
        """

    static let cart = """
        @Observable final class Cart {
            static let shared = Cart()
            static func preview() -> Cart { Cart() }
        }
        """

    static let leafMissingCartFromApp =
        "App.swift:1:64: error: `Leaf` needs `Cart`: App `MyApp` → Leaf (Leaf.swift:2)"

    static func file(_ path: String) throws -> String {
        try String(contentsOf: packageRoot.appendingPathComponent("Tests/Fixtures/" + path), encoding: .utf8)
    }

    static func app(showing content: String) -> String {
        "@main struct MyApp: App { var body: some Scene { WindowGroup { \(content) } } }"
    }
}
