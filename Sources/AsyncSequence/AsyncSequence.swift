import Foundation

let DISPATCH = DispatchQueue(label: "AsyncSequence", attributes: .concurrent)
let MAX_TASKS = ProcessInfo.processInfo.activeProcessorCount

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