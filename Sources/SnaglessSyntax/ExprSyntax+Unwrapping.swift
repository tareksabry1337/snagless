import SwiftSyntax

extension ExprSyntax {
    var unwrapped: ExprSyntax {
        var current = self
        while true {
            if let next = current.as(TryExprSyntax.self)?.expression
                ?? current.as(AwaitExprSyntax.self)?.expression
                ?? current.as(ForceUnwrapExprSyntax.self)?.expression
                ?? current.as(OptionalChainingExprSyntax.self)?.expression
            {
                current = next
            } else if let tuple = current.as(TupleExprSyntax.self), tuple.elements.count == 1,
                let only = tuple.elements.first, only.label == nil
            {
                current = only.expression
            } else {
                return current
            }
        }
    }

    var isForceUnwrapped: Bool {
        var current = self
        while true {
            if current.is(ForceUnwrapExprSyntax.self) {
                return true
            }
            if let next = current.as(TryExprSyntax.self)?.expression ?? current.as(AwaitExprSyntax.self)?.expression {
                current = next
            } else if let tuple = current.as(TupleExprSyntax.self), tuple.elements.count == 1,
                let only = tuple.elements.first, only.label == nil
            {
                current = only.expression
            } else {
                return false
            }
        }
    }

    var isSelf: Bool {
        self.as(DeclReferenceExprSyntax.self)?.baseName.text == "self"
    }
}
