import Foundation

struct DiagnosticsEntry: Codable {
    enum Source: String, Codable { case live, cached }
    let fetchDate: Date
    let source: Source
    let errorMessage: String?
    let totalFetches: Int
}
