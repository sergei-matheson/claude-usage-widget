import Foundation

struct UsageData: Codable, Equatable {
    let messagesUsed: Int
    let messagesLimit: Int
    let planName: String
    let periodResetDate: Date
    let modelBreakdown: [ModelUsage]
    let lastUpdated: Date

    static func placeholder() -> UsageData {
        UsageData(
            messagesUsed: 42,
            messagesLimit: 100,
            planName: "Pro",
            periodResetDate: Date().addingTimeInterval(86400 * 7),
            modelBreakdown: [
                ModelUsage(modelName: "claude-opus-4-7", messagesUsed: 10),
                ModelUsage(modelName: "claude-sonnet-4-6", messagesUsed: 32)
            ],
            lastUpdated: Date()
        )
    }
}

extension JSONDecoder {
    static var usageDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var usageEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
