import Foundation

public let DISPATCH = DispatchQueue(label: "Stream", attributes: .concurrent)
public let CPU_COUNT = ProcessInfo.processInfo.activeProcessorCount

public struct Stream<Base: Sequence> {
    // @usableFromInline
    internal var _base: Base

    /// Creates a sequence that has the same elements as `base`, but on
    /// which some operations such as `map` and `filter` are implemented
    /// lazily.
    // @inlinable // lazy-performance
    internal init(_ _base: Base) {
        self._base = _base
    }
}

extension Stream: LazySequenceProtocol {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator

    public func makeIterator() -> Self.Iterator {
        return _base.makeIterator()
    }
}

internal extension Stream {
    func apply<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (ConcurrentQueue<B?>, Element) throws -> Void
    ) -> Stream<AnySequence<B>> {
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

        return Stream<AnySequence>(sequence)
    }

    func map<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> B
    ) -> Stream<AnySequence<B>> {
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
    ) -> Stream<AnySequence<B>> where S.Element == B {
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
    ) -> Stream<AnySequence<Element>> {
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
    var stream: Stream<Self> {
        Stream(self)
    }
}

public extension Stream {
    var stream: Stream {
        self
    }
}