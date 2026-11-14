package struct MemberName: Hashable, CustomStringConvertible {
    package enum Labels: Hashable {
        case notCalled
        case called([String])
    }

    package let base: String
    package let labels: Labels

    package init(base: String, labels: Labels = .notCalled) {
        self.base = base
        self.labels = labels
    }

    package var description: String {
        switch labels {
        case .notCalled:
            return base
        case .called(let labels):
            return base + "(" + labels.map { $0 + ":" }.joined() + ")"
        }
    }
}
