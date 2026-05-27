import Foundation

enum UsageServiceError: Error {
    case unauthenticated
    case invalidOrganizationId
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(Error)
    case decodingError(Error)
    case unexpectedResponse(Int)
}

struct UsageService {
    // The claude.ai usage endpoint is undocumented. Verify the exact path by inspecting
    // network traffic on https://claude.ai/settings/usage before shipping.
    private let session: URLSession

<<<<<<< HEAD
    init() {
=======
    init(session: URLSession = UsageService.defaultSession) {
        self.session = session
    }

    static let defaultSession: URLSession = {
>>>>>>> origin/main
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // Internal init for testing — allows injecting a mock URLSession
    init(session: URLSession) {
        self.session = session
    }

    func fetchUsage(credentials: SessionCredentials) async throws -> UsageData {
        guard let url = buildURL(credentials: credentials) else {
            throw UsageServiceError.invalidOrganizationId
        }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(credentials.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("ClaudeUsageWidget/1.0 macOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageServiceError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageServiceError.unexpectedResponse(0)
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw UsageServiceError.unauthenticated
        case 429:
            throw UsageServiceError.rateLimited(retryAfter: Self.parseRetryAfter(http))
        default:
            throw UsageServiceError.unexpectedResponse(http.statusCode)
        }

        return try Self.parse(data: data)
    }

    // Decode a Claude usage payload into UsageData. Exposed for tests; not part of the public API
    // that views or providers should call.
    static func parse(data: Data) throws -> UsageData {
        do {
            return try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: data).toUsageData()
        } catch {
            throw UsageServiceError.decodingError(error)
        }
    }

    // Claude org IDs are UUIDs. Anything else is rejected so a hostile org-ID value
    // can't pivot the authenticated request to another claude.ai path.
    static let organizationIdPattern = #/^[A-Za-z0-9-]{1,64}$/#

    // Retry-After is either a delay in seconds or an HTTP-date. We honor the seconds form;
    // an HTTP-date is rare from claude.ai and falls back to the policy default.
    static func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)),
              seconds > 0 else { return nil }
        return seconds
    }

    func buildURL(credentials: SessionCredentials) -> URL? {
        if credentials.organizationId.isEmpty {
            return URL(string: "https://claude.ai/api/usage")
        }
        guard (try? Self.organizationIdPattern.wholeMatch(in: credentials.organizationId)) != nil else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "claude.ai"
        components.path = "/api/organizations/\(credentials.organizationId)/usage"
        return components.url
    }
}

private struct UsageBucket: Codable {
    let utilization: Double?
    let resetsAt: String?
}

private struct UsageAPIResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?

    func toUsageData() -> UsageData {
        let utilization = fiveHour?.utilization ?? 0
        let sevenDayUtilization = sevenDay?.utilization ?? 0

        return UsageData(
            fiveHourUtilization: Int(utilization.rounded()),
            periodResetDate: Self.parseDate(fiveHour?.resetsAt),
            sevenDayUtilization: Int(sevenDayUtilization.rounded()),
            sevenDayResetDate: Self.parseDate(sevenDay?.resetsAt),
            lastUpdated: Date()
        )
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return isoFractional.date(from: string) ?? isoBasic.date(from: string)
    }
}
