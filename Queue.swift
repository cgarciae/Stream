#!/home/cristian/.swift/tf-0.4.0-rc/usr/bin/swift
/*
 First-in first-out queue (FIFO)

 New elements are added to the end of the queue. Dequeuing pulls elements from
 the front of the queue.

 Enqueuing and dequeuing are O(1) operations.
 */
import Foundation

let DISPATCH = DispatchQueue(label: "AsyncSequence", attributes: .concurrent)
let MAX_TASKS = ProcessInfo.processInfo.activeProcessorCount

public enum QueueError: Error {
    case full
    case empty
}

public class Queue<T> {
    fileprivate var array = [T?]()
    fileprivate var head = 0

    private let maxSize: Int?

    init(maxSize: Int? = nil) {
        self.maxSize = maxSize
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public var count: Int {
        return array.count - head
    }

    public func put(_ element: T) throws {
        if let maxSize = maxSize, count == maxSize {
            throw QueueError.full
        }

        array.append(element)
    }

    public func get() throws -> T {
        if count == 0 {
            throw QueueError.empty
        }
        let element = array[head]!

        array[head] = nil
        head += 1

        let percentage = Double(head) / Double(array.count)

        if array.count > 50, percentage > 0.25 {
            array.removeFirst(head)
            head = 0
        }

        return element
    }

    public var front: T? {
        if isEmpty {
            return nil
        } else {
            return array[head]
        }
    }
}

public class ConcurrentQueue<T> {
    let lock = Lock()
    let second: Double = 1_000_000

    var queue: Queue<T>
    let timeSleep: Double

    init(maxSize: Int? = nil, timeSleep: Double = 0.001) {
        queue = Queue<T>(maxSize: maxSize)
        self.timeSleep = timeSleep
    }

    public var isEmpty: Bool { queue.isEmpty }
    public var count: Int { queue.count }
    public var front: T? { queue.front }
    public func put(_ element: T) {
        try! put(element, timeout: nil)
    }

    public func put(_ element: T, timeout: Double?) throws {
        let timeStart = Date()

        while true {
            do {
                try lock.aquire {
                    try queue.put(element)
                }
                break
            } catch QueueError.full {
                usleep(useconds_t(timeSleep * second))
            }

            if let timeout = timeout, timeStart.timeIntervalSinceNow.magnitude >= timeout {
                throw QueueError.full
            }
        }
    }

    public func get() -> T {
        return try! get(timeout: nil)
    }

    public func get(timeout: Double?) throws -> T {
        let timeStart = Date()
        var output: T?

        while true {
            do {
                try lock.aquire {
                    output = try queue.get()
                }
                return output!
            } catch QueueError.empty {
                usleep(useconds_t(timeSleep * second))
            }

            // print("timeout: \(timeout), interval: \(timeStart.timeIntervalSinceNow.magnitude)")
            if let timeout = timeout, timeStart.timeIntervalSinceNow.magnitude >= timeout {
                throw QueueError.empty
            }
        }
    }
}

public struct Lock {
    private var semaphore = DispatchSemaphore(value: 1)

    public func aquire(_ block: () throws -> Void) rethrows {
        semaphore.wait()
        defer { semaphore.signal() }

        try block()
    }
}

extension Sequence {
    func asyncApply<B>(
        maxTasks: Int? = MAX_TASKS,
        maxSize: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (ConcurrentQueue<B?>, Element) throws -> Void
    ) -> AnySequence<B> {
        return AnySequence<B> { () -> AnyIterator<B> in

            var first = true
            let queue = ConcurrentQueue<B?>(maxSize: maxSize)

            return AnyIterator<B> { () -> B? in
                if first {
                    first = false
                    let dispatch = dispatch ?? DISPATCH
                    // let dispatch = dispatch ?? DispatchQueue(label: UUID().uuidString, attributes: .concurrent)
                    let semaphore = maxTasks.map { DispatchSemaphore(value: $0) }

                    dispatch.async {
                        let group = DispatchGroup()

                        for elem in self {
                            group.enter()
                            semaphore?.wait()

                            dispatch.async {
                                try! f(queue, elem)

                                group.leave()
                                semaphore?.signal()
                            }
                        }
                        group.wait()
                        queue.put(nil)
                    }
                }

                return queue.get()
            }
        }
    }

    func asyncMap<B>(
        maxTasks: Int? = MAX_TASKS,
        maxSize: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> B
    ) -> AnySequence<B> {
        asyncApply(maxTasks: maxTasks, maxSize: maxSize, dispatch: dispatch) { queue, elem in
            queue.put(try! f(elem))
        }
    }

    func asyncFlatMap<B, S: Sequence>(
        maxTasks: Int? = MAX_TASKS,
        maxSize: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> S
    ) -> AnySequence<B> where S.Element == B {
        asyncApply(maxTasks: maxTasks, maxSize: maxSize, dispatch: dispatch) { queue, elem in
            for elem in try! f(elem) {
                queue.put(elem)
            }
        }
    }

    func asyncFilter(
        maxTasks: Int? = MAX_TASKS,
        maxSize: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> Bool
    ) -> AnySequence<Element> {
        asyncApply(maxTasks: maxTasks, maxSize: maxSize, dispatch: dispatch) { queue, elem in
            if try! f(elem) {
                queue.put(elem)
            }
        }
    }

    func asyncForEach(
        maxTasks: Int? = MAX_TASKS,
        maxSize: Int? = nil,
        dispatch: DispatchQueue? = nil,
        f: @escaping (Element) throws -> Void
    ) {
        asyncApply(maxTasks: maxTasks, maxSize: maxSize, dispatch: dispatch) { _, elem in
            try! f(elem)
        }.forEach {}
    }
}

func slow() {
    for i in 1 ... 100_000_000 {
        var b = i + 1
    }
}

_ = (1 ... 100)
    .asyncFilter {
        slow()
        return $0 % 2 == 0
    }
    .asyncMap { (x: Int) -> Int in
        slow()
        return -x
    }
    .asyncFlatMap { (x: Int) -> [Int] in
        slow()
        return [x, 1 - x]
    }
    .asyncForEach {
        slow()
        print($0)
    }

// let dispatch = DispatchQueue(label: "workers", attributes: .concurrent)
// var queue = ConcurrentQueue<Int>(maxSize: 10)
// var group = DispatchGroup()

// for _ in 1 ... 4 {
//     group.enter()
//     dispatch.async {
//         while true {
//             do {
//                 usleep(100_000)
//                 print(try queue.get(timeout: 0.1))
//             } catch {
//                 break
//             }
//         }
//         print("Exit")
//         group.leave()
//     }
// }

// print("inserting elements")
// for i in 1 ... 100 {
//     queue.put(i)
// }

// group.wait()
// print("done")

// public class Stage<T>: Sequence {
//     var queue: ConcurrentQueue<T?>
//     var group: DispatchGroup
//     var sequence: AnySequence<T>?
//     var start: (() -> Void)?

//     public init<S: Sequence>(queue: ConcurrentQueue<T?>, group: DispatchGroup, sequence: S) where S.Element == T {
//         self.group = group
//         self.queue = queue
//         self.sequence = AnySequence(sequence)
//         start = {
//             let dispatch = DispatchQueue(label: "queue", attributes: .concurrent)

//             dispatch.async {
//                 for elem in self.sequence! {
//                     self.queue.put(elem)
//                 }
//             }
//         }
//     }

//     public init(queue: ConcurrentQueue<T?>, group: DispatchGroup, start: @escaping () -> Void) {
//         self.group = group
//         self.queue = queue
//         self.start = start
//     }

//     public func makeIterator() -> AnyIterator<T> {
//         if let start = start {
//             start()
//         }

//         return AnyIterator {
//             self.queue.get()
//         }
//     }

//     public func map<B>(_: (T) throws -> B) rethrows -> Stage<B> {
//         let outputQueue = ConcurrentQueue<B?>()
//         let group = DispatchGroup()

//         return Stage<B>(queue: outputQueue, group: group) {
//             let dispatch = DispatchQueue(label: "queue", attributes: .concurrent)

//             for _ in 1 ... 4 {
//                 group.enter()
//                 dispatch.async {
//                     group.leave()
//                 }
//             }
//         }
//     }
// }