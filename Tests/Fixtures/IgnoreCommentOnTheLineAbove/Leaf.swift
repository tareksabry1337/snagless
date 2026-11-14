struct Leaf: View {
    // snagless: ignore Cart - set by the host before it shows
    @Environment(Cart.self) private var cart
    var body: some View { Text("leaf") }
}
