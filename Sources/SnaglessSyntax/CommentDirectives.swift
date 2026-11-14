import SnaglessModel
import SwiftSyntax

struct CommentDirectives {
    private struct Comment {
        let text: String
        let location: SnaglessModel.SourceLocation
        let lines: Set<Int>
    }

    let provides: [Int: [String]]
    let suppressions: [Suppression]
    let malformedSuppressions: [SnaglessModel.SourceLocation]

    static let providesMarker = "snagless: provides"
    static let ignoreMarker = "snagless: ignore"

    init(tree: SourceFileSyntax, source: String, converter: SourceLocationConverter) {
        let comments =
            source.contains(Self.providesMarker) || source.contains(Self.ignoreMarker)
            ? Self.comments(in: tree, converter: converter) : []
        var provides: [Int: [String]] = [:]
        var suppressions: [Suppression] = []
        var malformed: [SnaglessModel.SourceLocation] = []
        for comment in comments {
            if let marker = comment.text.range(of: Self.providesMarker) {
                let names = Self.body(of: comment.text, after: marker)
                    .split(separator: ",")
                    .compactMap { TypeReference.path(ofText: String($0)) }
                for line in comment.lines {
                    provides[line, default: []] += names
                }
            } else if let marker = comment.text.range(of: Self.ignoreMarker) {
                if let subject = Self.suppressedSubject(Self.body(of: comment.text, after: marker)) {
                    suppressions.append(
                        Suppression(subject: subject, location: comment.location, lines: comment.lines)
                    )
                } else {
                    malformed.append(comment.location)
                }
            }
        }
        self.provides = provides
        self.suppressions = suppressions
        malformedSuppressions = malformed
    }

    private static func body(of text: String, after marker: Range<String.Index>) -> String {
        text[marker.upperBound...].replacingOccurrences(of: "*/", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func suppressedSubject(_ body: String) -> Suppression.Subject? {
        guard let space = body.firstIndex(of: " ") else { return nil }
        let reason = body[space...].trimmingCharacters(in: .whitespaces)
            .trimmingPrefix(while: { $0 == "-" || $0 == "—" })
            .trimmingCharacters(in: .whitespaces)
        guard !reason.isEmpty else { return nil }
        let written = String(body[..<space])
        if written.hasPrefix("\\.") {
            let name = written.dropFirst(2)
            return name.isEmpty ? nil : .key(String(name))
        }
        return TypeReference.path(ofText: written).map(Suppression.Subject.type)
    }

    private static func comments(in tree: SourceFileSyntax, converter: SourceLocationConverter) -> [Comment] {
        var comments: [Comment] = []
        for token in tree.tokens(viewMode: .sourceAccurate) {
            let tokenLine = converter.location(for: token.positionAfterSkippingLeadingTrivia).line
            var offset = token.position
            for piece in token.leadingTrivia {
                if let text = piece.commentText {
                    let location = SnaglessModel.SourceLocation(converter.location(for: offset))
                    comments.append(Comment(text: text, location: location, lines: [location.line, tokenLine]))
                }
                offset += piece.sourceLength
            }
            offset = token.endPositionBeforeTrailingTrivia
            for piece in token.trailingTrivia {
                if let text = piece.commentText {
                    let location = SnaglessModel.SourceLocation(converter.location(for: offset))
                    comments.append(Comment(text: text, location: location, lines: [location.line]))
                }
                offset += piece.sourceLength
            }
        }
        return comments
    }
}

private extension SnaglessModel.SourceLocation {
    init(_ location: SwiftSyntax.SourceLocation) {
        self.init(line: location.line, column: location.column)
    }
}

private extension TriviaPiece {
    var commentText: String? {
        switch self {
        case .lineComment(let text), .blockComment(let text):
            return text
        default:
            return nil
        }
    }
}
