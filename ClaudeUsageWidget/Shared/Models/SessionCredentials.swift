import Foundation

enum CredentialsValidationResult: Equatable {
    case valid(token: String, organizationId: String)
    case emptyToken
    case invalidToken
    case invalidOrganizationId

    var statusMessage: String? {
        switch self {
        case .emptyToken:
            return "Session token can't be blank."
        case .valid:
            return nil
        case .invalidToken:
            return "Session token contains invalid characters."
        case .invalidOrganizationId:
            return "Organization ID must be alphanumeric (with dashes)."
        }
    }
}

struct SessionCredentials: Codable {
    let sessionKey: String
    let organizationId: String

    // Claude org IDs are UUIDs. Anything else is rejected so a hostile org-ID value
    // can't pivot the authenticated request to another claude.ai path.
    static let organizationIdPattern = #/^[A-Za-z0-9-]{1,64}$/#

    static let invalidTokenCharacters: CharacterSet = {
        var set = CharacterSet.controlCharacters
        // Cookie delimiters/quoting chars (RFC separators), control chars, and whitespace.
        // Blocking these avoids malformed Cookie header values and header-smuggling primitives.
        set.insert(charactersIn: ";,\"\\")
        set.formUnion(.whitespacesAndNewlines)
        return set
    }()

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeToken(_ token: String) -> String {
        normalize(token)
    }

    static func normalizeOrganizationId(_ organizationId: String) -> String {
        normalize(organizationId)
    }

    static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.rangeOfCharacter(from: invalidTokenCharacters) == nil
    }

    static func isValidOrganizationId(_ organizationId: String) -> Bool {
        (try? organizationIdPattern.wholeMatch(in: organizationId)) != nil
    }

    static func validateInput(token: String, organizationId: String) -> CredentialsValidationResult {
        let normalizedToken = normalizeToken(token)
        let normalizedOrg = normalizeOrganizationId(organizationId)
        guard !normalizedToken.isEmpty else { return .emptyToken }
        guard isValidToken(normalizedToken) else { return .invalidToken }
        guard normalizedOrg.isEmpty || isValidOrganizationId(normalizedOrg) else { return .invalidOrganizationId }
        return .valid(token: normalizedToken, organizationId: normalizedOrg)
    }
}
