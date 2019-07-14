import Foundation

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