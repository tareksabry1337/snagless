import SnaglessAnalysis

struct UsageError: Error {
    let message: String
}

enum OutputFormat: String {
    case text
    case github
}

struct Options {
    let previews: PreviewMode
    let format: OutputFormat
    let legacySheets: Bool
    let timing: Bool
    let verbose: Bool
    let targetGraph: String?
    let packages: [String]
    let stamp: String?
    let paths: [String]

    static let usage = """
        usage: snagless [--previews error|warning|off] [--format text|github] [--targets FILE] \
        [--package DIR]... [--stamp FILE] [--legacy-sheets] [--timing] [--verbose] [paths...]
               snagless --version
        """

    var analysis: AnalysisOptions {
        AnalysisOptions(previews: previews, legacySheets: legacySheets)
    }

    init(parsing arguments: [String]) throws(UsageError) {
        var previews = PreviewMode.error
        var format = OutputFormat.text
        var legacySheets = false
        var timing = false
        var verbose = false
        var targetGraph: String?
        var packages: [String] = []
        var stamp: String?
        var paths: [String] = []
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--previews":
                previews = try Self.choice(after: argument, from: &iterator, takes: "error, warning or off")
            case "--format":
                format = try Self.choice(after: argument, from: &iterator, takes: "text or github")
            case "--targets":
                targetGraph = try Self.value(after: argument, from: &iterator)
            case "--package":
                packages.append(try Self.value(after: argument, from: &iterator))
            case "--stamp":
                stamp = try Self.value(after: argument, from: &iterator)
            case "--legacy-sheets":
                legacySheets = true
            case "--timing":
                timing = true
            case "--verbose":
                verbose = true
            case "-h", "--help":
                throw UsageError(message: Self.usage)
            default:
                guard !argument.hasPrefix("--") else { throw UsageError(message: "unknown option \(argument)") }
                paths.append(argument)
            }
        }
        guard !paths.isEmpty || targetGraph != nil || !packages.isEmpty else { throw UsageError(message: Self.usage) }
        self.previews = previews
        self.format = format
        self.legacySheets = legacySheets
        self.timing = timing
        self.verbose = verbose
        self.targetGraph = targetGraph
        self.packages = packages
        self.stamp = stamp
        self.paths = paths
    }

    private static func choice<Choice: RawRepresentable<String>>(
        after flag: String,
        from iterator: inout IndexingIterator<[String]>,
        takes allowed: String,
    ) throws(UsageError) -> Choice {
        guard let chosen = Choice(rawValue: try value(after: flag, from: &iterator)) else {
            throw UsageError(message: "\(flag) takes \(allowed)")
        }
        return chosen
    }

    private static func value(
        after flag: String,
        from iterator: inout IndexingIterator<[String]>,
    ) throws(UsageError) -> String {
        guard let next = iterator.next() else { throw UsageError(message: "\(flag) needs a value") }
        return next
    }
}
