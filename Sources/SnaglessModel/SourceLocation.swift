package struct SourceLocation: Hashable, Comparable {
    package let line: Int
    package let column: Int

    package init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}
