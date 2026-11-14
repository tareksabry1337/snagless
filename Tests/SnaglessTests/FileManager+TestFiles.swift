import Foundation

extension FileManager {
    func makeTemporaryDirectory() throws -> URL {
        let url = temporaryDirectory.appendingPathComponent("snagless-\(UUID().uuidString)")
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func write(_ files: [String: String], under root: URL) throws {
        for (path, source) in files {
            let url = root.appendingPathComponent(path)
            try createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(source.utf8).write(to: url)
        }
    }
}
