import SnaglessAnalysis
import SnaglessModel
import SnaglessSyntax
import Testing

struct TestProject {
    let files: [SummarizedFile]

    static func analyze(_ files: [SummarizedFile], options: AnalysisOptions = AnalysisOptions()) -> Analysis {
        let analysis = Analysis(files, options: options)
        #expect(analysis.findingsWithoutPath == 0)
        return analysis
    }

    func analysis(options: AnalysisOptions = AnalysisOptions()) -> Analysis {
        Self.analyze(files, options: options)
    }

    func report(options: AnalysisOptions = AnalysisOptions()) -> Report {
        Report(analysis(options: options), verbose: true)
    }

    func errors(options: AnalysisOptions = AnalysisOptions()) -> [String] {
        report(options: options).output.split(separator: "\n").map(String.init)
    }

    var notes: [String] {
        report().notes.split(separator: "\n").map(String.init)
    }
}

extension TestProject {
    init(_ sources: [String: String], module: String = "App") {
        self.init(modules: [module: sources])
    }

    init(modules: [String: [String: String]]) {
        self.init(
            files: modules.flatMap { module, sources in
                sources.map { path, source in
                    SummarizedFile(
                        file: SourceFile(path: path, module: module),
                        summary: Summarizer.summarize(path: path, source: source),
                    )
                }
            }
        )
    }
}
