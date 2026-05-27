import XCTest
import Foundation

final class KeychainStoreTests: XCTestCase {

    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: "io.github.sergei-matheson.claudeusagewidget.tests.\(name)")
        // Ensure a clean slate before each test
        try? store.delete()
    }

    override func tearDown() {
        try? store.delete()
        super.tearDown()
    }

    // MARK: - Save & Load

    func testSaveAndLoad() throws {
        let credentials = SessionCredentials(sessionKey: "sk-test-123", organizationId: "org-456")
        try store.save(credentials)

        let loaded = try store.load()
        XCTAssertEqual(loaded.sessionKey, "sk-test-123")
        XCTAssertEqual(loaded.organizationId, "org-456")
    }

    func testSaveAndLoadWithEmptyOrganizationId() throws {
        let credentials = SessionCredentials(sessionKey: "sk-test-abc", organizationId: "")
        try store.save(credentials)

        let loaded = try store.load()
        XCTAssertEqual(loaded.sessionKey, "sk-test-abc")
        XCTAssertEqual(loaded.organizationId, "")
    }

    func testSaveUpdatesExistingCredentials() throws {
        try store.save(SessionCredentials(sessionKey: "old-key", organizationId: ""))
        try store.save(SessionCredentials(sessionKey: "new-key", organizationId: "org-new"))

        let loaded = try store.load()
        XCTAssertEqual(loaded.sessionKey, "new-key")
        XCTAssertEqual(loaded.organizationId, "org-new")
    }

    // MARK: - Load

    func testLoadThrowsNotFoundWhenEmpty() {
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.notFound)
        }
    }

    // MARK: - Delete

    func testDeleteRemovesCredentials() throws {
        try store.save(SessionCredentials(sessionKey: "sk-delete-me", organizationId: ""))
        try store.delete()

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.notFound)
        }
    }

    func testDeleteIsIdempotentWhenEmpty() {
        XCTAssertNoThrow(try store.delete())
    }
}

// MARK: - SessionCredentials Codable

final class SessionCredentialsTests: XCTestCase {

    func testRoundTrip() throws {
        let original = SessionCredentials(sessionKey: "sk-abc", organizationId: "org-xyz")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionCredentials.self, from: data)

        XCTAssertEqual(decoded.sessionKey, original.sessionKey)
        XCTAssertEqual(decoded.organizationId, original.organizationId)
    }

    func testRoundTripWithEmptyOrganizationId() throws {
        let original = SessionCredentials(sessionKey: "sk-abc", organizationId: "")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionCredentials.self, from: data)

        XCTAssertEqual(decoded.organizationId, "")
    }

    func testDecodesFromJSON() throws {
        let json = """
        {"sessionKey": "sk-from-json", "organizationId": "org-from-json"}
        """
        let decoded = try JSONDecoder().decode(SessionCredentials.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.sessionKey, "sk-from-json")
        XCTAssertEqual(decoded.organizationId, "org-from-json")
    }
}
