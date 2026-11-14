import SwiftSyntax

extension MemberBlockSyntax {
    var membersInEveryBranch: [MemberBlockItemSyntax] {
        Self.flatten(members)
    }

    private static func flatten(_ members: MemberBlockItemListSyntax) -> [MemberBlockItemSyntax] {
        members.flatMap { member -> [MemberBlockItemSyntax] in
            guard let config = member.decl.as(IfConfigDeclSyntax.self) else { return [member] }
            return config.clauses.flatMap { clause -> [MemberBlockItemSyntax] in
                guard case .decls(let decls) = clause.elements else { return [] }
                return flatten(decls)
            }
        }
    }
}
