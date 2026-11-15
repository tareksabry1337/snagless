import Foundation
import SnaglessModel
import SnaglessSyntax

package struct SummaryBatch {
    package let files: [SummarizedFile]
}

package struct UnreadableFiles: Error {
    package let paths: [String]
}

extension SummaryBatch {
    package init(_ sources: [SourceFile]) throws(UnreadableFiles) {
        let summaries = Workers.map(count: sources.count) { index -> SummarizedFile? in
            let file = sources[index]
            guard let content = FileManager.default.contents(atPath: file.path),
                let source = String(bytes: content, encoding: .utf8)
            else { return nil }
            return SummarizedFile(file: file, summary: Summarizer.summarize(path: file.path, source: source))
        }
        let unreadable = zip(sources, summaries).filter { $0.1 == nil }.map(\.0.path)
        guard unreadable.isEmpty else { throw UnreadableFiles(paths: unreadable) }
        files = summaries.compactMap { $0 }
    }
}
