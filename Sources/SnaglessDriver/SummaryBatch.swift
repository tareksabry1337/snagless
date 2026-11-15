import Foundation
import SnaglessModel
import SnaglessSyntax

package struct SummaryBatch {
    package let files: [SummarizedFile]
}

package struct NonUTF8Files: Error {
    package let paths: [String]
}

extension SummaryBatch {
    package init(_ sources: [SourceFile]) throws(NonUTF8Files) {
        let summaries = Workers.map(count: sources.count) { index -> SummarizedFile? in
            let file = sources[index]
            guard let content = FileManager.default.contents(atPath: file.path),
                let source = String(bytes: content, encoding: .utf8)
            else { return nil }
            return SummarizedFile(file: file, summary: Summarizer.summarize(path: file.path, source: source))
        }
        let nonUTF8 = zip(sources, summaries).filter { $0.1 == nil }.map(\.0.path)
        guard nonUTF8.isEmpty else { throw NonUTF8Files(paths: nonUTF8) }
        files = summaries.compactMap { $0 }
    }
}
