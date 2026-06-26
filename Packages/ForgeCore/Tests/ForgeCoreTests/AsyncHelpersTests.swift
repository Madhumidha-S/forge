import XCTest
@testable import ForgeCore

final class AsyncHelpersTests: XCTestCase {

    func testParallelMapPreservesOrderAndCounts() async throws {
        let input = [1, 2, 3, 4, 5]
        let output = try await parallelMap(input) { item in
            // Small async hop to guarantee concurrency is exercised.
            try await Task.sleep(for: .milliseconds(5))
            return item * 2
        }

        XCTAssertEqual(output, [2, 4, 6, 8, 10])
        XCTAssertEqual(output.count, input.count)
    }

    func testParallelMapPropagatesErrors() async {
        let input = [1, 2, 3]

        do {
            _ = try await parallelMap(input) { item -> Int in
                if item == 2 {
                    throw TestError.boom
                }
                return item
            }
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}

private enum TestError: Error {
    case boom
}
