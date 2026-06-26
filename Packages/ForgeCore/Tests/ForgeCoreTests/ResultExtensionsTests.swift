import XCTest
@testable import ForgeCore

final class ResultExtensionsTests: XCTestCase {

    func testAsyncMapSuccess() async throws {
        let result: Result<Int, TestError> = .success(21)
        let mapped = await result.asyncMap { value -> Int in
            value * 2
        }
        XCTAssertEqual(try mapped.get(), 42)
    }

    func testAsyncMapFailure() async {
        let result: Result<Int, TestError> = .failure(.boom)
        let mapped = await result.asyncMap { value -> Int in
            value * 2
        }

        switch mapped {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error, .boom)
        }
    }

    func testInitCatchingSuccess() async {
        let result = await Result<Int, Error>(catching: {
            try await Task.sleep(for: .nanoseconds(1))
            return 7
        })
        XCTAssertEqual(try result.get(), 7)
    }

    func testInitCatchingFailure() async {
        struct ThrowingError: Error, Equatable {}
        let result = await Result<Int, Error>(catching: {
            try await Task.sleep(for: .nanoseconds(1))
            throw ThrowingError()
        })

        XCTAssertThrowsError(try result.get())
    }
}

private enum TestError: Error, Equatable {
    case boom
}
