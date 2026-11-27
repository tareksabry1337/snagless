import SnaglessAnalysis
import SnaglessModel
import Foundation

package enum GitHubAnnotations {
    package static func render(_ diagnostics: [Diagnostic]) -> String {
        diagnostics.flatMap { diagnostic in
            [
                diagnostic.rendered,
                command(diagnostic.severity.rawValue, diagnostic.path, diagnostic.location, diagnostic.message),
            ] + diagnostic.notes.map { command("notice", $0.path, $0.location, $0.message) }
        }
        .map { $0 + "\n" }
        .joined()
    }

    private static func command(
        _ kind: String,
        _ path: String,
        _ location: SourceLocation,
        _ message: String,
    ) -> String {
        let file = URL(fileURLWithPath: path).standardized.path
        let properties = "file=\(escapedProperty(file)),line=\(location.line),col=\(location.column),title=Snagless"
        return "::\(kind) \(properties)::\(escapedMessage(message))"
    }

    private static func escapedMessage(_ text: String) -> String {
        text.replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
    }

    private static func escapedProperty(_ text: String) -> String {
        escapedMessage(text)
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ",", with: "%2C")
    }
}
