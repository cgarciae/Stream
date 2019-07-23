import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(StreamTests.allTests),
            testCase(OrderedStreamTests.allTests),
        ]
    }
#endif