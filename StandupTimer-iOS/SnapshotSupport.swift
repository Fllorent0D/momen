#if DEBUG
import Foundation
import StandupKit

extension MeetingManager {
    /// Under `fastlane snapshot` (launch arg `UITEST_SEED`), populate a realistic
    /// demo team + stats history so the App Store screenshots aren't empty.
    /// Deterministic values keep the shots identical across languages/devices.
    func seedForSnapshotIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_SEED") else { return }

        let team = ["Alex", "Marie", "Sam", "Yuki", "Omar"]
        meeting.participants = team.map { Participant(name: $0, isPresent: true) }
        meeting.totalDuration = 15 * 60
        meeting.countdownEnabled = false   // start goes straight to the running timer

        var records: [MeetingRecord] = []
        for _ in 0..<10 {
            let speakers = team.prefix(4).enumerated().map { idx, name in
                SpeakerRecord(participantName: name,
                              allocatedTime: 225,
                              actualTime: Double(165 + idx * 40))
            }
            records.append(MeetingRecord(presetName: "Daily",
                                         speakers: Array(speakers),
                                         totalDuration: 900))
        }
        statsStore.records = records
        badgeStore.evaluate(records: records)
    }
}
#endif
