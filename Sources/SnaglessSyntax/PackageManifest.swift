import SwiftParser
import SwiftSyntax

package struct PackageManifest {
    package struct Target: Equatable {
        package let name: String
        package let path: String?

        package init(name: String, path: String?) {
            self.name = name
            self.path = path
        }
    }

    package let targets: [Target]
    package let localPackagePaths: [String]

    package init(source: String) {
        let reader = ManifestReader(viewMode: .sourceAccurate)
        reader.walk(Parser.parse(source: source))
        targets = reader.targets
        localPackagePaths = reader.localPackagePaths
    }
}

private final class ManifestReader: SyntaxVisitor {
    private static let sourceTargetKinds: Set<String> = ["target", "executableTarget"]

    private(set) var targets: [PackageManifest.Target] = []
    private(set) var localPackagePaths: [String] = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let access = node.calledExpression.as(MemberAccessExprSyntax.self), access.base == nil else {
            return .visitChildren
        }
        let kind = access.declName.baseName.text
        let path = Self.stringArgument("path", of: node)
        if Self.sourceTargetKinds.contains(kind), let name = Self.stringArgument("name", of: node) {
            targets.append(PackageManifest.Target(name: name, path: path))
        } else if kind == "package", let path {
            localPackagePaths.append(path)
        }
        return .visitChildren
    }

    private static func stringArgument(_ label: String, of call: FunctionCallExprSyntax) -> String? {
        let argument = call.arguments.first { $0.label?.text == label }
        return argument?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
    }
}
