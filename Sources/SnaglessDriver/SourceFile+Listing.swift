import SnaglessModel
import Foundation

extension SourceFile {
    private static let skippedDirectories: Set<String> = [
        ".build", "DerivedData", "Pods", "Carthage", "checkouts", ".git", "node_modules",
    ]

    package static func list(_ paths: [String]) -> [SourceFile] {
        var files: [SourceFile] = []
        for path in paths {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                files += swiftFiles(inDirectory: path)
            } else if path.hasSuffix(".swift") {
                let url = URL(fileURLWithPath: path).standardized
                let folder = url.deletingLastPathComponent().lastPathComponent
                files.append(SourceFile(path: path, module: packageModuleName(url.pathComponents) ?? folder))
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    static func swiftFiles(inDirectory path: String, module: String? = nil) -> [SourceFile] {
        let root = URL(fileURLWithPath: path).standardized
        let prefix = path.hasSuffix("/") ? path : path + "/"
        return relativeSwiftPaths(in: path)
            .map { SourceFile(path: prefix + $0, module: module ?? moduleName(of: $0, under: root)) }
    }

    private static func packageModuleName(_ components: [String], from start: Int = 0) -> String? {
        for index in components.indices.reversed() where index >= start && index + 2 < components.count {
            if components[index] == "Sources" || components[index] == "Tests" {
                return components[index + 1]
            }
        }
        return nil
    }

    private static func moduleName(of relativePath: String, under root: URL) -> String {
        let components = relativePath.split(separator: "/").map(String.init)
        let topFolder = components.count > 1 ? components[0] : root.lastPathComponent
        return packageModuleName(root.pathComponents + components, from: root.pathComponents.count - 2) ?? topFolder
    }

    private static func relativeSwiftPaths(in path: String) -> [String] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: path).standardized,
                includingPropertiesForKeys: [],
            )
        else { return [] }
        var paths: [String] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if skippedDirectories.contains(name) {
                enumerator.skipDescendants()
            } else if name.hasSuffix(".swift") {
                paths.append(url.pathComponents.suffix(enumerator.level).joined(separator: "/"))
            }
        }
        return paths
    }
}
