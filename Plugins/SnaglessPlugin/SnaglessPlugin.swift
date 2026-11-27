import Foundation
import PackagePlugin

private struct TargetGraphBuilder {
    private(set) var graph = TargetGraph(targets: [])
    private var seen: Set<String> = []

    mutating func add(id: String, module: String, files: [URL]) {
        guard seen.insert(id).inserted else { return }
        let paths = files.filter { $0.pathExtension == "swift" }.map { $0.path(percentEncoded: false) }.sorted()
        graph.targets.append(TargetGraph.Target(module: module, files: paths))
    }

    mutating func addWithDependencies(_ target: SourceModuleTarget) {
        for source in [target] + target.recursiveTargetDependencies.compactMap({ $0 as? SourceModuleTarget }) {
            add(id: source.id, module: source.moduleName, files: source.sourceFiles(withSuffix: "swift").map(\.url))
        }
    }
}

private struct CheckCommand {
    static let skippedDirectories: Set<String> = [
        ".build", "DerivedData", "Pods", "Carthage", "checkouts", ".git", "node_modules",
    ]

    let tool: URL
    let workDirectory: URL
    let name: String
    let graph: TargetGraph
    let directories: [URL]
    let packages: [URL]
    let stamp: URL?

    func commands() throws -> [Command] {
        let graphFile = workDirectory.appending(path: "targets.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let encoded = try encoder.encode(graph)
        if (try? Data(contentsOf: graphFile)) != encoded {
            try encoded.write(to: graphFile, options: .atomic)
        }
        var arguments = ["--targets", graphFile.path(percentEncoded: false)]
        if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true" {
            arguments += ["--format", "github"]
        }
        if let stamp {
            arguments += ["--stamp", stamp.path(percentEncoded: false)]
        }
        arguments += packages.flatMap { ["--package", $0.path(percentEncoded: false)] }
        arguments += directories.map { $0.path(percentEncoded: false) }
        return [
            .buildCommand(
                displayName: "Snagless \(name)",
                executable: tool,
                arguments: arguments,
                inputFiles: inputFiles + [graphFile],
                outputFiles: stamp.map { [$0] } ?? [],
            )
        ]
    }

    private var inputFiles: [URL] {
        let graphFiles = graph.targets.flatMap(\.files).map { URL(filePath: $0) }
        let scanned = (directories + packages).flatMap(Self.swiftFiles(under:))
        var seen: Set<String> = []
        return (graphFiles + scanned).filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func swiftFiles(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if skippedDirectories.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
            } else if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }
}

@main
struct SnaglessPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }
        var builder = TargetGraphBuilder()
        builder.addWithDependencies(sourceTarget)
        return try CheckCommand(
            tool: context.tool(named: "snagless").url,
            workDirectory: context.pluginWorkDirectoryURL,
            name: target.name,
            graph: builder.graph,
            directories: [],
            packages: [],
            stamp: nil,
        )
        .commands()
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SnaglessPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let project = context.xcodeProject
        var builder = TargetGraphBuilder()
        for projectTarget in [target] + project.targets {
            builder.add(projectTarget)
        }
        let projectFile = project.directoryURL.appending(path: project.displayName + ".xcodeproj")
        let packages = try ProjectFile.localPackages(in: projectFile, relativeTo: project.directoryURL)
        return try CheckCommand(
            tool: context.tool(named: "snagless").url,
            workDirectory: context.pluginWorkDirectoryURL,
            name: target.displayName,
            graph: builder.graph,
            directories: [project.directoryURL],
            packages: packages,
            stamp: context.pluginWorkDirectoryURL.appending(path: "SnaglessPassed.swift"),
        )
        .commands()
    }
}

private struct UnreadableProject: Error, CustomStringConvertible {
    let path: String

    var description: String { "Snagless needs the objects list in \(path) to find the project's local packages" }
}

private enum ProjectFile {
    static func localPackages(in projectFile: URL, relativeTo projectDirectory: URL) throws -> [URL] {
        try relativePaths(in: projectFile).map { projectDirectory.appending(path: $0).standardizedFileURL }
    }

    private static func relativePaths(in projectFile: URL) throws -> [String] {
        let json = projectFile.appending(path: "project.xcproj")
        if FileManager.default.fileExists(atPath: json.path(percentEncoded: false)) {
            let root = try JSONSerialization.jsonObject(with: Data(contentsOf: json), options: .json5Allowed)
            let packages = (root as? [String: Any])?["packages"] as? [[String: Any]] ?? []
            return packages.filter { $0["kind"] as? String == "local" }.compactMap { $0["path"] as? String }
        }
        let propertyList = projectFile.appending(path: "project.pbxproj")
        let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: propertyList), format: nil)
        guard let objects = (root as? [String: Any])?["objects"] as? [String: [String: Any]] else {
            throw UnreadableProject(path: propertyList.path(percentEncoded: false))
        }
        return objects.values
            .filter { $0["isa"] as? String == "XCLocalSwiftPackageReference" }
            .compactMap { $0["relativePath"] as? String }
            .sorted()
    }
}

extension TargetGraphBuilder {
    mutating func add(_ target: XcodeTarget) {
        let files = target.inputFiles.filter { $0.type == .source }.map(\.url)
        add(id: target.id, module: Self.moduleName(target.product?.name ?? target.displayName), files: files)
    }

    private static func moduleName(_ productName: String) -> String {
        let name = String(productName.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" })
        return name.first?.isNumber == true ? "_" + name : name
    }
}
#endif
