/*
 First-in first-out queue (FIFO)

 New elements are added to the end of the queue. Dequeuing pulls elements from
 the front of the queue.

 Enqueuing and dequeuing are O(1) operations.
 */
import Foundation

public enum QueueError: Error {
    case full
    case empty
}

public class Queue<T> {
    fileprivate var array = [T?]()
    fileprivate var head = 0

    private let maxSize: Int?

    public init(maxSize: Int? = nil) {
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

    public func nothing() {}
}