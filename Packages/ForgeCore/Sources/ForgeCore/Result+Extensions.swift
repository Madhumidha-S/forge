import Foundation

public extension Result {
    /// Transforms the success value asynchronously.
    ///
    /// - Parameter transform: An async closure that converts `Success` into `NewSuccess`.
    /// - Returns: A new `Result` with the transformed success or the original failure.
    func asyncMap<NewSuccess>(
        _ transform: (Success) async throws -> NewSuccess
    ) async rethrows -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let value):
            return .success(try await transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

public extension Result where Failure == Error {
    /// Creates a `Result` by awaiting a throwing closure.
    ///
    /// - Parameter body: An async closure that produces the success value.
    init(catching body: () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
