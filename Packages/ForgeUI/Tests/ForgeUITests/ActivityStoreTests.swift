import XCTest
@testable import ForgeUI

/// Tests for the in-memory ring-buffer activity log used by the
/// Activity screen. The store is `@MainActor`, so all test methods
/// must also be `@MainActor` to satisfy the isolation requirement.
@MainActor
final class ActivityStoreTests: XCTestCase {
    // MARK: - Test 1: append ordering

    func testAppendAddsEntriesInOrder() {
        let store = ActivityStore()
        XCTAssertTrue(store.entries.isEmpty)

        store.append(level: .info, message: "first")
        store.append(level: .info, message: "second")
        store.append(level: .info, message: "third")

        XCTAssertEqual(store.entries.count, 3)
        XCTAssertEqual(store.entries[0].message, "first")
        XCTAssertEqual(store.entries[1].message, "second")
        XCTAssertEqual(store.entries[2].message, "third")
    }

    // MARK: - Test 2: ring-buffer trim at maxEntries

    func testAppendTrimsAtMaxEntries() {
        let store = ActivityStore()

        // Append one more than the cap so the oldest entry falls off.
        let overflow = ActivityStore.maxEntries + 1
        for index in 0..<overflow {
            store.append(level: .info, message: "entry-\(index)")
        }

        XCTAssertEqual(store.entries.count, ActivityStore.maxEntries)
        // Oldest entry ("entry-0") should have been trimmed; the buffer
        // should now start at "entry-1".
        XCTAssertEqual(store.entries.first?.message, "entry-1")
        XCTAssertEqual(store.entries.last?.message, "entry-\(overflow - 1)")
    }

    // MARK: - Test 3: clear()

    func testClearEmptiesEntries() {
        let store = ActivityStore()
        store.append(level: .info, message: "alpha")
        store.append(level: .warning, message: "beta")
        XCTAssertEqual(store.entries.count, 2)

        store.clear()

        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - Test 4: info / warning / error convenience methods

    func testConvenienceMethodsUseCorrectLevels() {
        let store = ActivityStore()

        store.info("an info message")
        store.warning("a warning message")
        store.error("an error message")

        XCTAssertEqual(store.entries.count, 3)
        XCTAssertEqual(store.entries[0].level, .info)
        XCTAssertEqual(store.entries[0].message, "an info message")
        XCTAssertEqual(store.entries[1].level, .warning)
        XCTAssertEqual(store.entries[1].message, "a warning message")
        XCTAssertEqual(store.entries[2].level, .error)
        XCTAssertEqual(store.entries[2].message, "an error message")
    }
}
