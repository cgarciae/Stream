import Foundation

public struct Stream<Element> {
    // @usableFromInline
    internal var base: AnySequence<Element>

    /// Creates a sequence that has the same elements as `base`, but on
    /// which some operations such as `map` and `filter` are implemented
    /// lazily.
    // @inlinable // lazy-performance
    internal init<S: Sequence>(_ base: S) where S.Element == Element {
        self.base = AnySequence<Element>(base)
    }

    internal init(_ base: AnySequence<Element>) {
        self.base = base
    }
}

extension Stream: LazySequenceProtocol {
    public typealias Element = Element
    public typealias Iterator = AnySequence<Element>.Iterator

    public func makeIterator() -> Self.Iterator {
        return base.makeIterator()
    }
}

internal extension Stream {
    func apply<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (ConcurrentQueue<B?>, Element) throws -> Void
    ) -> Stream<B> {
        let sequence = AnySequence<B> { () -> AnyIterator<B> in

            var first = true
            let queue = ConcurrentQueue<B?>(maxSize: queueMax)

            return AnyIterator<B> { () -> B? in
                if first {
                    first = false
                    let dispatch = dispatch ?? DISPATCH
                    // let dispatch = dispatch ?? DispatchQueue(label: UUID().uuidString, attributes: .concurrent)
                    let semaphore = DispatchSemaphore(value: maxTasks)

                    dispatch.async {
                        let group = DispatchGroup()

                        for elem in self {
                            group.enter()
                            semaphore.wait()

                            dispatch.async {
                                try! f(queue, elem)

                                group.leave()
                                semaphore.signal()
                            }
                        }
                        group.wait()
                        queue.put(nil)
                    }
                }

                return queue.get()
            }
        }

        return Stream<B>(sequence)
    }

    func map<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> B
    ) -> Stream<B> {
        apply(
            maxTasks: maxTasks,
            queueMax: queueMax,
            dispatch: dispatch
        ) { queue, elem in
            queue.put(try! f(elem))
        }
    }

    func flatMap<B, S: Sequence>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> S
    ) -> Stream<B> where S.Element == B {
        apply(
            maxTasks: maxTasks,
            queueMax: queueMax,
            dispatch: dispatch
        ) { queue, elem in
            for elem in try! f(elem) {
                queue.put(elem)
            }
        }
    }

    func filter(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> Bool
    ) -> Stream<Element> {
        apply(maxTasks: maxTasks, queueMax: queueMax, dispatch: dispatch) { queue, elem in
            if try! f(elem) {
                queue.put(elem)
            }
        }
    }

    func forEach(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> Void
    ) {
        apply(
            maxTasks: maxTasks,
            queueMax: queueMax,
            dispatch: dispatch
        ) { _, elem in
            try! f(elem)
        }
        .makeIterator()
        .forEach {}
    }
}

public extension Sequence {
    var stream: Stream<Element> {
        Stream(self)
    }
}

public extension Stream {
    var stream: Stream {
        self
    }
}