extension StringProtocol {
    var isTypeName: Bool {
        drop { $0 == "_" }.first?.isUppercase == true
    }
}
