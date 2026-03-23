import Foundation

struct Participant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var isPresent: Bool

    init(name: String = "", isPresent: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isPresent = isPresent
    }
}
