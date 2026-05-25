import Foundation

struct UsageData: Codable, Equatable {
    let messagesUsed: Int
    let messagesLimit: Int
    let planName: String
    let periodResetDate: Date
    let sevenDayUtilization: Int
    let sevenDayResetDate: Date
    let lastUpdated: Date

    static func placeholder() -> UsageData {
        UsageData(
            messagesUsed: 42,
            messagesLimit: 100,
            planName: "Pro",
            periodResetDate: Date().addingTimeInterval(3600 * 3),
            sevenDayUtilization: 18,
            sevenDayResetDate: Date().addingTimeInterval(86400 * 5),
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
