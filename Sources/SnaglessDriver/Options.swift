import SnaglessAnalysis

struct UsageError: Error {
    let message: String
}

struct Options {
    let previews: PreviewMode
    let legacySheets: Bool
    let timing: Bool
    let verbose: Bool
    let targetGraph: String?
    let packages: [String]
    let stamp: String?
    let paths: [String]

    static let usage = """
        usage: snagless [--previews error|warning|off] [--targets FILE] [--package DIR]... \
        [--stamp FILE] [--legacy-sheets] [--timing] [--verbose] [paths...]
               snagless --version
        """

    var analysis: AnalysisOptions {
        AnalysisOptions(previews: previews, legacySheets: legacySheets)
    }

    init(parsing arguments: [String]) throws(UsageError) {
        var previews = PreviewMode.error
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
                let raw = try Self.value(after: argument, from: &iterator)
                guard let mode = PreviewMode(rawValue: raw) else {
                    throw UsageError(message: "--previews takes error, warning or off")
                }
                previews = mode
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
        self.legacySheets = legacySheets
        self.timing = timing
        self.verbose = verbose
        self.targetGraph = targetGraph
        self.packages = packages
        self.stamp = stamp
        self.paths = paths
    }

    private static func value(
        after flag: String,
        from iterator: inout IndexingIterator<[String]>,
    ) throws(UsageError) -> String {
        guard let next = iterator.next() else { throw UsageError(message: "\(flag) needs a value") }
        return next
    }
}
