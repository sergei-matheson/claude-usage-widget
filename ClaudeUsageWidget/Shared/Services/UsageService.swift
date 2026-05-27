import Foundation

enum UsageServiceError: Error {
    case unauthenticated
    case invalidOrganizationId
    case networkError(Error)
    case decodingError(Error)
    case unexpectedResponse(Int)
}

struct UsageService {
    // The claude.ai usage endpoint is undocumented. Verify the exact path by inspecting
    // network traffic on https://claude.ai/settings/usage before shipping.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

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
            throw UsageServiceError.unexpectedResponse(429)
        default:
            throw UsageServiceError.unexpectedResponse(http.statusCode)
        }

        do {
            let apiResponse = try JSONDecoder.usageDecoder.decode(UsageAPIResponse.self, from: data)
            return apiResponse.toUsageData()
        } catch {
            throw UsageServiceError.decodingError(error)
        }
    }

    // Claude org IDs are UUIDs. Anything else is rejected so a hostile org-ID value
    // can't pivot the authenticated request to another claude.ai path.
    static let organizationIdPattern = #/^[A-Za-z0-9-]{1,64}$/#

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

struct UsageBucket: Codable {
    let utilization: Double?
    let resetsAt: String?
}

struct UsageAPIResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?

    func toUsageData() -> UsageData {
        let utilization = fiveHour?.utilization ?? 0
        let resetDate = parseDate(fiveHour?.resetsAt) ?? Date().addingTimeInterval(3600 * 5)
        let sevenDayUtilization = sevenDay?.utilization ?? 0
        let sevenDayResetDate = parseDate(sevenDay?.resetsAt) ?? Date().addingTimeInterval(86400 * 7)

        return UsageData(
            fiveHourUtilization: Int(utilization.rounded()),
            periodResetDate: resetDate,
            sevenDayUtilization: Int(sevenDayUtilization.rounded()),
            sevenDayResetDate: sevenDayResetDate,
            lastUpdated: Date()
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
