import SnaglessModel

struct Needs {
    let direct: [[TypeName: RequirementSource]]
    let all: [NeedSet]
    let passes: Int

    init(index: NodeIndex, links: Links) {
        direct = index.nodes.map { node in
            var table: [TypeName: RequirementSource] = [:]
            for requirement in node.requirements where table[requirement.type] == nil {
                table[requirement.type] = requirement.source
            }
            return table
        }
        var all = direct.map { NeedSet(fromParent: Set($0.keys)) }
        var passes = 0
        let children = links.nodes
        let order = Self.childrenFirstOrder(children)
        var changed = true
        while changed {
            changed = false
            passes += 1
            for node in order {
                for edge in children[node] where !edge.startsEmpty && edge.node != node {
                    if all[node].formUnion(edge.carry(all[edge.node])) {
                        changed = true
                    }
                }
            }
        }
        self.all = all
        self.passes = passes
    }

    private struct Visit {
        let node: Int
        var nextChild: Int
    }

    private enum Mark {
        case unvisited
        case open
        case done
    }

    private static func childrenFirstOrder(_ children: [[LinkedChild]]) -> [Int] {
        var order: [Int] = []
        order.reserveCapacity(children.count)
        var marks = [Mark](repeating: .unvisited, count: children.count)
        for start in children.indices where marks[start] == .unvisited {
            var stack = [Visit(node: start, nextChild: 0)]
            marks[start] = .open
            while var top = stack.popLast() {
                guard top.nextChild < children[top.node].count else {
                    marks[top.node] = .done
                    order.append(top.node)
                    continue
                }
                let child = children[top.node][top.nextChild].node
                top.nextChild += 1
                stack.append(top)
                if marks[child] == .unvisited {
                    marks[child] = .open
                    stack.append(Visit(node: child, nextChild: 0))
                }
            }
        }
        return order
    }
}

struct Reachability {
    let nodes: Set<Int>

    init(links: Links, from roots: some Sequence<Int>) {
        var reached: Set<Int> = []
        var stack: [Int] = []
        for child in roots.flatMap({ links.roots[$0] }) where reached.insert(child.node).inserted {
            stack.append(child.node)
        }
        while let node = stack.popLast() {
            for child in links.nodes[node] where reached.insert(child.node).inserted {
                stack.append(child.node)
            }
        }
        nodes = reached
    }
}
