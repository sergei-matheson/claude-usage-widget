import XCTest
import Foundation

// MARK: - EntryState

final class EntryStateTests: XCTestCase {

    func testLoadedEqualsLoaded() {
        XCTAssertEqual(EntryState.loaded, EntryState.loaded)
    }

    func testUnauthenticatedEqualsUnauthenticated() {
        XCTAssertEqual(EntryState.unauthenticated, EntryState.unauthenticated)
    }

    func testErrorEqualsErrorWithSameMessage() {
        XCTAssertEqual(EntryState.error("oops"), EntryState.error("oops"))
    }

    func testErrorDoesNotEqualErrorWithDifferentMessage() {
        XCTAssertNotEqual(EntryState.error("a"), EntryState.error("b"))
    }

    func testLoadedDoesNotEqualUnauthenticated() {
        XCTAssertNotEqual(EntryState.loaded, EntryState.unauthenticated)
    }

    func testLoadedDoesNotEqualError() {
        XCTAssertNotEqual(EntryState.loaded, EntryState.error(""))
    }

    func testUnauthenticatedDoesNotEqualError() {
        XCTAssertNotEqual(EntryState.unauthenticated, EntryState.error(""))
    }
}

// MARK: - UsageEntry

final class UsageEntryTests: XCTestCase {

    // MARK: - placeholder

    func testPlaceholderHasLoadedState() {
        XCTAssertEqual(UsageEntry.placeholder().state, .loaded)
    }

    func testPlaceholderHasNonNilUsageData() {
        XCTAssertNotNil(UsageEntry.placeholder().usageData)
    }

    func testPlaceholderDateIsRecent() {
        let before = Date()
        let entry = UsageEntry.placeholder()
        let after = Date()
        XCTAssertGreaterThanOrEqual(entry.date, before)
        XCTAssertLessThanOrEqual(entry.date, after)
    }

    // MARK: - unauthenticated

    func testUnauthenticatedHasUnauthenticatedState() {
        XCTAssertEqual(UsageEntry.unauthenticated().state, .unauthenticated)
    }

    func testUnauthenticatedHasNilUsageData() {
        XCTAssertNil(UsageEntry.unauthenticated().usageData)
    }

    // MARK: - error

    func testErrorEntryHasErrorState() {
        let entry = UsageEntry.error("Network failed")
        XCTAssertEqual(entry.state, .error("Network failed"))
    }

    func testErrorEntryHasNilUsageData() {
        XCTAssertNil(UsageEntry.error("something went wrong").usageData)
    }

    func testErrorEntryPreservesMessage() {
        let message = "Rate limited. Retrying in 1 hour."
        let entry = UsageEntry.error(message)
        guard case .error(let captured) = entry.state else {
            XCTFail("Expected .error state")
            return
        }
        XCTAssertEqual(captured, message)
    }

    func testErrorEntryWithEmptyMessage() {
        let entry = UsageEntry.error("")
        XCTAssertEqual(entry.state, .error(""))
    }
}
