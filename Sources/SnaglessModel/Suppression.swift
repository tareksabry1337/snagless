package struct Suppression: Hashable {
    package enum Subject: Hashable, CustomStringConvertible {
        case type(String)
        case key(String)

        package var description: String {
            switch self {
            case .type(let path):
                return path
            case .key(let name):
                return "\\." + name
            }
        }
    }

    package let subject: Subject
    package let location: SourceLocation
    package let lines: Set<Int>

    package init(subject: Subject, location: SourceLocation, lines: Set<Int>) {
        self.subject = subject
        self.location = location
        self.lines = lines
    }
}
