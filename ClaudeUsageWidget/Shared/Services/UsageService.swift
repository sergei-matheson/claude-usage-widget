import Foundation

enum UsageServiceError: Error {
    case unauthenticated
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
        let url = buildURL(credentials: credentials)
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

    private func buildURL(credentials: SessionCredentials) -> URL {
        if credentials.organizationId.isEmpty {
            return URL(string: "https://claude.ai/api/usage")!
        }
        return URL(string: "https://claude.ai/api/organizations/\(credentials.organizationId)/usage")!
    }
}

// All fields optional to survive undocumented API schema changes.
private struct UsageAPIResponse: Codable {
    let messagesUsed: Int?
    let messagesLimit: Int?
    let plan: String?
    let resetDate: String?
    let models: [UsageAPIModelEntry]?

    func toUsageData() -> UsageData {
        let resetDate: Date
        if let dateString = self.resetDate,
           let parsed = ISO8601DateFormatter().date(from: dateString) {
            resetDate = parsed
        } else {
            resetDate = Date().addingTimeInterval(86400 * 30)
        }

        return UsageData(
            messagesUsed: messagesUsed ?? 0,
            messagesLimit: messagesLimit ?? 0,
            planName: plan.map { $0.capitalized } ?? "Unknown",
            periodResetDate: resetDate,
            modelBreakdown: (models ?? []).map {
                ModelUsage(modelName: $0.name ?? "Unknown", messagesUsed: $0.messages ?? 0)
            },
            lastUpdated: Date()
        )
    }
}

private struct UsageAPIModelEntry: Codable {
    let name: String?
    let messages: Int?
}
