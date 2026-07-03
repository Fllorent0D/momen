import Foundation

public struct Participant: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var isPresent: Bool
    public var avatarData: Data?

    public init(name: String = "", isPresent: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isPresent = isPresent
        self.avatarData = nil
    }

    public var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
