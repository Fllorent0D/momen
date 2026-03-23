import Foundation

struct Participant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var isPresent: Bool
    var avatarData: Data?

    init(name: String = "", isPresent: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isPresent = isPresent
        self.avatarData = nil
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
