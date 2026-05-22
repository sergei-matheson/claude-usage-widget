import Foundation

enum EntryState: Equatable {
    case loaded
    case unauthenticated
    case error(String)
}
