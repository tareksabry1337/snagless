import SwiftSyntax

extension SyntaxProtocol {
    var boundNames: [String] {
        if let identifier = self.as(IdentifierPatternSyntax.self) {
            return [identifier.identifier.text]
        }
        if self.is(ClosureExprSyntax.self) {
            return []
        }
        return children(viewMode: .sourceAccurate).flatMap(\.boundNames)
    }

    var containsCrashingCall: Bool {
        tokens(viewMode: .sourceAccurate).contains { StandardLibraryAPI.crashingCalls.contains($0.text) }
    }

    var isTypeDeclaration: Bool {
        self.is(StructDeclSyntax.self) || self.is(ClassDeclSyntax.self) || self.is(EnumDeclSyntax.self)
            || self.is(ActorDeclSyntax.self) || self.is(ProtocolDeclSyntax.self) || self.is(ExtensionDeclSyntax.self)
    }
}
