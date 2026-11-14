import SnaglessModel
import Foundation

extension SourceFile {
    package static func list(targetGraph path: String) throws -> [SourceFile] {
        let graph = try JSONDecoder().decode(TargetGraph.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        var modules: [String: String] = [:]
        for target in graph.targets {
            for file in target.files where file.hasSuffix(".swift") && modules[file] == nil {
                modules[file] = target.module
            }
        }
        return modules.map { SourceFile(path: $0.key, module: $0.value) }.sorted { $0.path < $1.path }
    }
}
