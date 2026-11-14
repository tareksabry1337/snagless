import SnaglessAnalysis
import SnaglessModel
import SnaglessSyntax

struct TestProject {
    let files: [SummarizedFile]

    func report(options: AnalysisOptions = AnalysisOptions()) -> Report {
        Report(Analysis(files, options: options), verbose: true)
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
