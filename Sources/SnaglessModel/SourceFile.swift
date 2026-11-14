package struct SourceFile: Hashable {
    package let path: String
    package let module: String

    package init(path: String, module: String) {
        self.path = path
        self.module = module
    }
}

package struct SummarizedFile {
    package let file: SourceFile
    package var summary: FileSummary

    package init(file: SourceFile, summary: FileSummary) {
        self.file = file
        self.summary = summary
    }
}
