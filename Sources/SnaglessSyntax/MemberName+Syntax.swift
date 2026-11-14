import SnaglessModel
import SwiftSyntax

extension MemberName {
    init(_ function: FunctionDeclSyntax) {
        self.init(
            base: function.name.text,
            labels: .called(function.signature.parameterClause.parameters.map(\.firstName.text)),
        )
    }

    init(_ name: String, calledWith call: FunctionCallExprSyntax) {
        self.init(base: name, labels: .called(call.arguments.map { $0.label?.text ?? "_" }))
    }
}
