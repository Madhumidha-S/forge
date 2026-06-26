import Foundation

/// Maps a collection concurrently while preserving input order.
///
/// This helper uses `withThrowingTaskGroup` to run `transform` for every item
/// in parallel. Results are collected in the same order as `items`.
///
/// - Important: If any transformation throws, the error propagates immediately
///   and the task group cancels any outstanding work.
///
/// - Parameters:
///   - items: The collection to transform.
///   - transform: An async, throwing, `Sendable` closure applied to each item.
/// - Returns: An array of transformed values in the original order.
public func parallelMap<T: Sendable, R: Sendable>(
    _ items: [T],
    _ transform: @escaping @Sendable (T) async throws -> R
) async throws -> [R] {
    try await withThrowingTaskGroup(of: (Int, R).self) { group in
        for (index, item) in items.enumerated() {
            group.addTask {
                (index, try await transform(item))
            }
        }

        var results = [R?](repeating: nil, count: items.count)
        for try await (index, value) in group {
            results[index] = value
        }
        return results.map { $0! }
    }
}
