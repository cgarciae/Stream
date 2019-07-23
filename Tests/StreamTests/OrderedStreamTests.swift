@testable import Stream
import XCTest

final class OrderedStreamTests: XCTestCase {
    func testMap() {
        let async = (1 ... 10).stream.inOrder.map { $0 + 1 }
        let sync = (1 ... 10).map { $0 + 1 }

        XCTAssertEqual(Array(async), Array(sync))
    }

    func testFilter() {
        let async = (1 ... 10).stream.inOrder.filter { $0 % 2 == 0 }
        let sync = (1 ... 10).filter { $0 % 2 == 0 }

        XCTAssertEqual(Array(async), Array(sync))
    }

    func testFlatMap() {
        let async = (1 ... 10).stream.inOrder.flatMap { [$0, -$0] }
        let sync = (1 ... 10).flatMap { [$0, -$0] }

        XCTAssertEqual(Array(async), Array(sync))
    }

    func testForEach() {
        var async = [Int]()
        var sync = [Int]()
        let lock = Lock()

        (1 ... 10).stream.inOrder.forEach { x in lock.aquire { async.append(x) } }
        (1 ... 10).forEach { sync.append($0) }

        XCTAssertEqual(Set(async), Set(sync))
    }

    static var allTests = [
        ("testMap", testMap),
        ("testFilter", testFilter),
        ("testFlatMap", testFlatMap),
        ("testForEach", testForEach),
    ]
}