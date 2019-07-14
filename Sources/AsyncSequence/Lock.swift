import Foundation

public struct Lock {
    private var semaphore = DispatchSemaphore(value: 1)

    public func aquire(_ block: () throws -> Void) rethrows {
        semaphore.wait()
        defer { semaphore.signal() }

        try block()
    }
}