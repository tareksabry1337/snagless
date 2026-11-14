extension StringProtocol {
    var startsWithUppercase: Bool {
        guard let first else { return false }
        return first.isUppercase
    }
}
