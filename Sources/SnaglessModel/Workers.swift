import Dispatch
import Foundation

private final class WorkQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0
    private let count: Int

    init(count: Int) {
        self.count = count
    }

    func take() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard next < count else { return nil }
        next += 1
        return next - 1
    }
}

private final class Slots<Element: Sendable>: @unchecked Sendable {
    let buffer: UnsafeMutablePointer<Element?>
    let count: Int

    init(count: Int) {
        self.count = count
        buffer = .allocate(capacity: count)
        buffer.initialize(repeating: nil, count: count)
    }

    deinit {
        buffer.deinitialize(count: count)
        buffer.deallocate()
    }
}

private final class SharedElements<Element: Sendable>: @unchecked Sendable {
    let base: UnsafeMutablePointer<Element>

    init(_ base: UnsafeMutablePointer<Element>) {
        self.base = base
    }
}

package enum Workers {
    private static let stackSize = 64 << 20

    package static func map<Element: Sendable>(
        count: Int,
        _ transform: @escaping @Sendable (Int) -> Element,
    ) -> [Element] {
        let slots = Slots<Element>(count: count)
        forEach(count: count) { index in
            slots.buffer[index] = transform(index)
        }
        return (0..<count).compactMap { slots.buffer[$0] }
    }

    package static func replace<Element: Sendable>(
        _ elements: inout [Element],
        _ transform: @escaping @Sendable (consuming Element) -> Element,
    ) {
        elements.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            let shared = SharedElements(base)
            forEach(count: buffer.count) { index in
                let element = (shared.base + index).move()
                (shared.base + index).initialize(to: transform(element))
            }
        }
    }

    private static func forEach(count: Int, _ body: @escaping @Sendable (Int) -> Void) {
        let queue = WorkQueue(count: count)
        let group = DispatchGroup()
        for _ in 0..<max(1, min(ProcessInfo.processInfo.activeProcessorCount, count)) {
            group.enter()
            let thread = Thread {
                while let index = queue.take() {
                    body(index)
                }
                group.leave()
            }
            thread.stackSize = stackSize
            thread.start()
        }
        group.wait()
    }
}
