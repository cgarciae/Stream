import Foundation

struct Index<Element> {
    let index: Int
    let isLast: Bool
    let element: Element?
}

enum ElementOrganizerError: Error {
    case noneLastElement
}

enum NextElement<Element> {
    case none
    case next(Element)
    case ended
}

class ElementOrganizer<Element> {
    var buffer: [Int: [Element]] = [:]
    var finished: Set<Int> = []
    var current: Int = 0

    func insert(_ index: Index<Element>) {
        ///////////////////////////////
        // insert
        ///////////////////////////////
        let element = index.element
        let isLast = index.isLast
        let index = index.index

        if let element = element {
            addToBuffer(element, at: index)
        }

        if isLast {
            finished.insert(index)
        }
    }

    func next() -> NextElement<Element> {
        ///////////////////////////////
        // next
        ///////////////////////////////

        if var elements = buffer[current], elements.count > 0 {
            let element = elements.removeFirst()
            buffer[current] = elements

            return .next(element)

        } else if finished.contains(current) {
            buffer.removeValue(forKey: current)
            finished.remove(current)
            current += 1

            return .none

        } else if buffer.count > 0 || finished.count > 0 {
            return .none
        } else {
            return .ended
        }
    }

    func addToBuffer(_ element: Element, at index: Int) {
        var elements = buffer[index] ?? []
        elements.append(element)
        buffer[index] = elements
    }
}

public struct OrderedStream<Element> {
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

extension OrderedStream: LazySequenceProtocol {
    public typealias Element = Element
    public typealias Iterator = AnySequence<Element>.Iterator

    public func makeIterator() -> Self.Iterator {
        return base.makeIterator()
    }
}

internal extension OrderedStream {
    func apply<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (ConcurrentQueue<Index<B>?>, Int, Element) throws -> Void
    ) -> OrderedStream<B> {
        let sequence = AnySequence<B> { () -> AnyIterator<B> in

            var first = true
            var queueOpen = true
            let queue = ConcurrentQueue<Index<B>?>(maxSize: queueMax)
            let organizer = ElementOrganizer<B>()

            return AnyIterator<B> { () -> B? in
                if first {
                    first = false
                    let dispatch = dispatch ?? DISPATCH
                    // let dispatch = dispatch ?? DispatchQueue(label: UUID().uuidString, attributes: .concurrent)
                    let semaphore = DispatchSemaphore(value: maxTasks)

                    dispatch.async {
                        let group = DispatchGroup()

                        for (i, elem) in self.enumerated() {
                            group.enter()
                            semaphore.wait()

                            dispatch.async {
                                try! f(queue, i, elem)

                                group.leave()
                                semaphore.signal()
                            }
                        }
                        group.wait()
                        queue.put(nil)
                    }
                }

                while true {
                    if queueOpen, let element = queue.get() {
                        organizer.insert(element)
                    } else {
                        queueOpen = false
                    }

                    let next = organizer.next()
                    switch next {
                    case let .next(nextElement):
                        return nextElement
                    case .none:
                        continue
                    case .ended:
                        return nil
                    }
                }
            }
        }

        return OrderedStream<B>(sequence)
    }

    func map<B>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> B
    ) -> OrderedStream<B> {
        apply(
            maxTasks: maxTasks,
            queueMax: queueMax,
            dispatch: dispatch
        ) { queue, i, elem in
            queue.put(Index(
                index: i,
                isLast: true,
                element: try! f(elem)
            ))
        }
    }

    func flatMap<B, S: Sequence>(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> S
    ) -> OrderedStream<B> where S.Element == B {
        apply(
            maxTasks: maxTasks,
            queueMax: queueMax,
            dispatch: dispatch
        ) { queue, i, elem in
            for elem in try! f(elem) {
                queue.put(Index(
                    index: i,
                    isLast: false,
                    element: elem
                ))
            }
            queue.put(Index(
                index: i,
                isLast: true,
                element: nil
            ))
        }
    }

    func filter(
        maxTasks: Int = CPU_COUNT,
        queueMax: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> Bool
    ) -> OrderedStream<Element> {
        apply(maxTasks: maxTasks, queueMax: queueMax, dispatch: dispatch) {
            queue, i, elem in
            if try! f(elem) {
                queue.put(Index(
                    index: i,
                    isLast: true,
                    element: elem
                ))
            } else {
                queue.put(Index(
                    index: i,
                    isLast: true,
                    element: nil
                ))
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
        ) { _, i, elem in
            try! f(elem)
        }
        .makeIterator()
        .forEach {}
    }
}

public extension Stream {
    var ordered: OrderedStream<Element> {
        OrderedStream(base)
    }
}