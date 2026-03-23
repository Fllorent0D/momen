import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct Participant: Identifiable, Hashable, Codable, Transferable {
    let id: UUID
    var name: String
    var isPresent: Bool

    init(name: String = "", isPresent: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isPresent = isPresent
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .participant)
    }
}

extension UTType {
    static let participant = UTType(exportedAs: "be.floca.standup-timer.participant")
}
