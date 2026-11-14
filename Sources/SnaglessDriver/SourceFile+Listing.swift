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

    static func swiftFiles(inDirectory path: String, module: String) -> [SourceFile] {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        return relativeSwiftPaths(in: path).map { SourceFile(path: prefix + $0, module: module) }
    }

    private static func packageModuleName(_ components: [String], from start: Int = 0) -> String? {
        for index in components.indices.reversed() where index >= start && index + 2 < components.count {
            if components[index] == "Sources" || components[index] == "Tests" {
                return components[index + 1]
            }
        }
        return nil
    }

    private static func swiftFiles(inDirectory path: String) -> [SourceFile] {
        let root = URL(fileURLWithPath: path).standardized
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let rootComponents = root.pathComponents
        return relativeSwiftPaths(in: path)
            .map { relative in
                let components = relative.split(separator: "/").map(String.init)
                let topFolder = components.count > 1 ? components[0] : root.lastPathComponent
                let module =
                    packageModuleName(rootComponents + components, from: rootComponents.count - 2) ?? topFolder
                return SourceFile(path: prefix + relative, module: module)
            }
    }

    private static func relativeSwiftPaths(in path: String) -> [String] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: path).standardized,
                includingPropertiesForKeys: [],
                options: [.producesRelativePathURLs],
            )
        else { return [] }
        var paths: [String] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if skippedDirectories.contains(name) {
                enumerator.skipDescendants()
            } else if name.hasSuffix(".swift") {
                paths.append(url.relativePath)
            }
        }
        return paths
    }
}
