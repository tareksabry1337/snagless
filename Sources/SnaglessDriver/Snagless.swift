import SnaglessAnalysis
import SnaglessModel
import Foundation

public enum Snagless {
    static let version = "snagless 0.9.2"

    public static func main(arguments: [String]) -> Int32 {
        if arguments == ["--version"] {
            FileHandle.standardOutput.write(Data((version + "\n").utf8))
            return 0
        }
        do {
            return try run(try Options(parsing: arguments))
        } catch {
            FileHandle.standardError.write(Data((error.message + "\n").utf8))
            return 2
        }
    }

    private static func listFiles(_ options: Options) throws(UsageError) -> [SourceFile] {
        try checkInputsExist(options)
        var fromGraph: [SourceFile] = []
        if let graphPath = options.targetGraph {
            do {
                fromGraph = try SourceFile.list(targetGraph: graphPath)
            } catch {
                throw UsageError(
                    message: "--targets \(graphPath) must be a readable target graph: \(error.localizedDescription)"
                )
            }
        }
        return firstOfEachPath(fromGraph + SourceFile.list(packages: options.packages) + SourceFile.list(options.paths))
    }

    private static func checkInputsExist(_ options: Options) throws(UsageError) {
        for path in options.paths where !FileManager.default.fileExists(atPath: path) {
            throw UsageError(message: "\(path) must be an existing file or folder")
        }
        for package in options.packages {
            let manifest = URL(fileURLWithPath: package).appendingPathComponent("Package.swift").path
            guard FileManager.default.fileExists(atPath: manifest) else {
                throw UsageError(message: "--package \(package) must be a folder with a Package.swift")
            }
        }
    }

    private static func run(_ options: Options) throws(UsageError) -> Int32 {
        let clock = ContinuousClock()
        let start = clock.now
        let files = try listFiles(options)
        let listed = clock.now
        let batch: SummaryBatch
        do {
            batch = try SummaryBatch(files)
        } catch {
            throw UsageError(message: error.paths.map { "\($0) must be readable UTF-8 text" }.joined(separator: "\n"))
        }
        let summarized = clock.now
        let analysis = Analysis((consume batch).files, options: options.analysis)
        let analyzed = clock.now

        let report = Report(analysis, verbose: options.verbose)
        FileHandle.standardOutput.write(Data(report.output.utf8))
        FileHandle.standardError.write(Data(report.notes.utf8))
        let errors = report.diagnostics.filter { $0.severity == .error }.count
        var summary = summaryLine(
            analysis,
            fileCount: files.count,
            errors: errors,
            warnings: report.diagnostics.count - errors,
        )
        if options.timing {
            summary +=
                "timing: list \(milliseconds(listed - start)) ms, "
                + "parse+summarize \(milliseconds(summarized - listed)) ms, "
                + "graph \(milliseconds(analyzed - summarized)) ms, "
                + "total \(milliseconds(clock.now - start)) ms\n"
        }
        FileHandle.standardError.write(Data(summary.utf8))
        if let stamp = options.stamp {
            if errors > 0 {
                try? FileManager.default.removeItem(atPath: stamp)
            } else {
                _ = FileManager.default.createFile(atPath: stamp, contents: Data())
            }
        }
        return errors > 0 ? 1 : 0
    }

    package static func summaryLine(_ analysis: Analysis, fileCount: Int, errors: Int, warnings: Int) -> String {
        let stats = analysis.stats
        let counts = [
            counted(fileCount, "file") + " (\(analysis.unreadablePaths.count) with syntax errors)",
            counted(stats.views, "view"),
            counted(stats.edges, "edge"),
            counted(stats.requirements, "requirement"),
            counted(stats.roots, "root"),
            counted(stats.reachableViews, "reachable view"),
            counted(stats.uncheckedViews, "unchecked view"),
            counted(stats.unresolvedInjections, "unresolved injection"),
            counted(stats.fixpointPasses, "fixpoint pass", plural: "fixpoint passes"),
            counted(errors, "error"),
            counted(warnings, "warning"),
            "\(stats.activeSuppressions) ignored by comments",
        ]
        return "snagless: " + counts.joined(separator: ", ") + "\n"
    }

    private static func counted(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        let noun = count == 1 ? singular : plural ?? singular + "s"
        return "\(count) \(noun)"
    }

    private static func firstOfEachPath(_ files: [SourceFile]) -> [SourceFile] {
        var seen: Set<String> = []
        return files.filter { seen.insert(URL(fileURLWithPath: $0.path).standardized.path).inserted }
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        return String(format: "%.1f", Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15)
    }
}
