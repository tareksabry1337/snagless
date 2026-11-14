struct TargetGraph: Codable {
    struct Target: Codable {
        let module: String
        let files: [String]
    }

    var targets: [Target]
}
