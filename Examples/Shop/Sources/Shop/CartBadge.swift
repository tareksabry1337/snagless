import Observation
import SwiftUI

@Observable
public final class Cart {
    public var count = 0
    public init() {}
}

public struct CartBadge: View {
    @Environment(Cart.self)
    private var cart

    public init() {}

    public var body: some View {
        Text("\(cart.count)")
    }
}
