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

    var forceUnwrappedOperand: ExprSyntax? {
        var current = self
        while true {
            if let operand = current.as(ForceUnwrapExprSyntax.self)?.expression {
                return operand
            }
            if let next = current.as(TryExprSyntax.self)?.expression ?? current.as(AwaitExprSyntax.self)?.expression {
                current = next
            } else if let tuple = current.as(TupleExprSyntax.self), tuple.elements.count == 1,
                let only = tuple.elements.first, only.label == nil
            {
                current = only.expression
            } else {
                return nil
            }
        }
    }

    var chainsOptionally: Bool {
        switch self.as(ExprSyntaxEnum.self) {
        case .optionalChainingExpr:
            return true
        case .memberAccessExpr(let access):
            return access.base?.chainsOptionally ?? false
        case .functionCallExpr(let call):
            return call.calledExpression.chainsOptionally
        case .subscriptCallExpr(let call):
            return call.calledExpression.chainsOptionally
        case .forceUnwrapExpr(let unwrap):
            return unwrap.expression.chainsOptionally
        default:
            return false
        }
    }

    var isSelf: Bool {
        self.as(DeclReferenceExprSyntax.self)?.baseName.text == "self"
    }
}
