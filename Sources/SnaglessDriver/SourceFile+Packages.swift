import SnaglessModel
import SnaglessSyntax
import Foundation

extension SourceFile {
    private static let defaultSourceFolders = ["Sources", "Source", "src", "srcs"]

    package static func list(packages roots: [String]) -> [SourceFile] {
        var pending = roots.map { URL(fileURLWithPath: $0).standardized }
        var visited: Set<String> = []
        var files: [SourceFile] = []
        while let root = pending.popLast() {
            guard visited.insert(root.path).inserted,
                let manifest = FileManager.default.contents(atPath: root.appendingPathComponent("Package.swift").path),
                let source = String(bytes: manifest, encoding: .utf8)
            else { continue }
            let package = PackageManifest(source: source)
            for target in package.targets {
                guard let directory = sourceDirectory(of: target, in: root) else { continue }
                files += swiftFiles(inDirectory: directory.path, module: target.name)
            }
            pending += package.localPackagePaths.map { root.appendingPathComponent($0).standardized }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func sourceDirectory(of target: PackageManifest.Target, in root: URL) -> URL? {
        if let path = target.path {
            return root.appendingPathComponent(path)
        }
        return defaultSourceFolders.lazy
            .map { root.appendingPathComponent($0).appendingPathComponent(target.name) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
