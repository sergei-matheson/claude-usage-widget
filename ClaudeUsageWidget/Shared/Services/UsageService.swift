import Foundation
import OSLog

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
    private let logger = Logger(subsystem: BundleIdentifiers.base, category: "UsageService")

    init(session: URLSession = UsageService.defaultSession) {
        self.session = session
    }

    static let defaultSession: URLSession = {
        // Authenticated requests should not persist cookies/cache to disk.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    func fetchUsage(credentials: SessionCredentials) async throws -> UsageData {
        guard let url = buildURL(credentials: credentials) else {
            throw UsageServiceError.invalidOrganizationId
        }
        logger.debug("Fetching usage from \(url.absoluteString, privacy: .public)")

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(credentials.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("ClaudeUsageWidget/1.0 macOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw UsageServiceError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageServiceError.unexpectedResponse(0)
        }

        switch http.statusCode {
        case 200:
            logger.info("Fetch succeeded")
        case 401, 403:
            logger.warning("Unauthenticated — session token may be expired")
            throw UsageServiceError.unauthenticated
        case 429:
            let retryAfter = Self.parseRetryAfter(http)
            logger.warning("Rate limited; retry-after=\(retryAfter ?? -1, privacy: .public)")
            throw UsageServiceError.rateLimited(retryAfter: retryAfter)
        default:
            logger.error("Unexpected HTTP \(http.statusCode, privacy: .public)")
            throw UsageServiceError.unexpectedResponse(http.statusCode)
        }

        do {
            return try Self.parse(data: data)
        } catch {
            logger.error("Decoding failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
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
        guard SessionCredentials.isValidOrganizationId(credentials.organizationId) else {
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
        return UsageData(
            fiveHourUtilization: Self.normalizedPercent(fiveHour?.utilization),
            periodResetDate: Self.parseDate(fiveHour?.resetsAt),
            sevenDayUtilization: Self.normalizedPercent(sevenDay?.utilization),
            sevenDayResetDate: Self.parseDate(sevenDay?.resetsAt),
            lastUpdated: Date()
        )
    }

    private static func normalizedPercent(_ value: Double?) -> Int {
        guard let value, value.isFinite else { return 0 }
        let rounded = Int(value.rounded())
        return min(max(rounded, 0), 100)
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
