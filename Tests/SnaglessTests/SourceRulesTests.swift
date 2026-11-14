import Foundation
import SwiftParser
import SwiftSyntax
import Testing

private final class SourceRules: SyntaxVisitor {
    static let trappingCalls: Set<String> = ["fatalError", "precondition", "preconditionFailure", "assertionFailure"]
    static let jargonWords: Set<String> = ["corpus", "corpora", "walk", "program"]

    private let converter: SourceLocationConverter
    private var violations: [String] = []

    private init(_ tree: SourceFileSyntax, path: String) {
        converter = SourceLocationConverter(fileName: path, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    static func violations(in source: String, path: String) -> [String] {
        let tree = Parser.parse(source: source)
        let rules = SourceRules(tree, path: path)
        rules.walk(tree)
        return jargon(in: path).map { "\(path): file name uses `\($0)`" } + rules.violations
    }

    static func jargon(in name: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in name {
            let startsWord = character.isUppercase && current.last?.isLowercase == true
            if character.isLetter && !startsWord {
                current.append(character)
                continue
            }
            words.append(current.lowercased())
            current = character.isLetter ? String(character) : ""
        }
        words.append(current.lowercased())
        return words.filter(jargonWords.contains)
    }

    private func record(_ node: some SyntaxProtocol, _ what: String) {
        let location = node.startLocation(converter: converter)
        violations.append("\(location.file):\(location.line): \(what)")
    }

    private func checkName(_ token: TokenSyntax) {
        for word in Self.jargon(in: token.text) {
            record(token, "name `\(token.text)` uses `\(word)`")
        }
    }

    private func isTopLevel(_ node: some SyntaxProtocol) -> Bool {
        node.parent?.parent?.parent?.is(SourceFileSyntax.self) == true
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
            Self.trappingCalls.contains(name)
        {
            record(node, name)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if isTopLevel(node) {
            record(node, "top-level function `\(node.name.text)`")
        }
        checkName(node.name)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if isTopLevel(node) {
            record(node, "top-level variable")
        }
        return .visitChildren
    }

    override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.identifier)
        return .visitChildren
    }

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.firstName)
        if let secondName = node.secondName {
            checkName(secondName)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.name)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.name)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind {
        checkName(node.name)
        return .visitChildren
    }
}

@Suite
struct SourceRulesTests {
    @Test
    func everyRuleIsFound() {
        let source = """
            func helper() {}
            let shared = 1
            struct CorpusLoader {
                func walkTree(program: Int) -> Int {
                    let corpora = 1
                    fatalError("x")
                }
                enum Kind { case program }
                func fine() { precondition(ok); preconditionFailure(); assertionFailure() }
            }
            """
        #expect(
            SourceRules.violations(in: source, path: "Sidewalk.swift") == [
                "Sidewalk.swift:1: top-level function `helper`",
                "Sidewalk.swift:2: top-level variable",
                "Sidewalk.swift:3: name `CorpusLoader` uses `corpus`",
                "Sidewalk.swift:4: name `walkTree` uses `walk`",
                "Sidewalk.swift:4: name `program` uses `program`",
                "Sidewalk.swift:5: name `corpora` uses `corpora`",
                "Sidewalk.swift:6: fatalError",
                "Sidewalk.swift:8: name `program` uses `program`",
                "Sidewalk.swift:9: precondition",
                "Sidewalk.swift:9: preconditionFailure",
                "Sidewalk.swift:9: assertionFailure",
            ]
        )
        #expect(
            SourceRules.violations(in: "", path: "Scripts/gen_corpus.py") == [
                "Scripts/gen_corpus.py: file name uses `corpus`"
            ]
        )
    }

    @Test
    func sourcesFollowTheRules() throws {
        let root = Fixture.packageRoot
        var files: [String] = []
        for directory in ["Sources", "Plugins", "Tests/SnaglessTests", "Scripts"] {
            let enumerator = FileManager.default.enumerator(atPath: root.appendingPathComponent(directory).path)
            while let path = enumerator?.nextObject() as? String {
                files.append(directory + "/" + path)
            }
        }
        #expect(files.contains("Sources/snagless/main.swift"))
        #expect(files.contains("Plugins/SnaglessPlugin/SnaglessPlugin.swift"))
        #expect(files.contains("Tests/SnaglessTests/SourceRulesTests.swift"))
        var found: [String] = []
        for file in files {
            let source =
                file.hasSuffix(".swift")
                ? try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8) : ""
            found += SourceRules.violations(in: source, path: file)
        }
        #expect(found == [])
    }

    @Test
    func pluginSkipsTheSameDirectoriesAsTheTool() throws {
        func skippedDirectories(in path: String) throws -> [String] {
            let source = try String(contentsOf: Fixture.packageRoot.appendingPathComponent(path), encoding: .utf8)
            let tree = Parser.parse(source: source)
            let binding = tree.tokens(viewMode: .sourceAccurate)
                .first { $0.text == "skippedDirectories" }?
                .parent?
                .parent?
                .as(PatternBindingSyntax.self)
            let elements = binding?.initializer?.value.as(ArrayExprSyntax.self)?.elements ?? []
            return elements.compactMap { $0.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue }
        }
        let tool = try skippedDirectories(in: "Sources/SnaglessDriver/SourceFile+Listing.swift")
        #expect(tool.contains(".build"))
        #expect(try skippedDirectories(in: "Plugins/SnaglessPlugin/SnaglessPlugin.swift") == tool)
    }
}
