import Foundation
import SnaglessModel
import SnaglessSyntax

package struct SummaryBatch {
    package let files: [SummarizedFile]
}

extension SummaryBatch {
    package init(_ sources: [SourceFile]) {
        files =
            Workers.map(count: sources.count) { index -> SummarizedFile? in
                let file = sources[index]
                guard let content = FileManager.default.contents(atPath: file.path),
                    let source = String(bytes: content, encoding: .utf8)
                else { return nil }
                return SummarizedFile(file: file, summary: Summarizer.summarize(path: file.path, source: source))
            }
            .compactMap { $0 }
    }
}
