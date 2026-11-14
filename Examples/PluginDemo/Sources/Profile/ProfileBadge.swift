import Observation
import SwiftUI

@Observable
public final class Session {
    public var name = "guest"
    public init() {}
}

public struct ProfileBadge: View {
    @Environment(Session.self)
    private var session

    public init() {}

    public var body: some View {
        Text(session.name)
    }
}
