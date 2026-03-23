import Foundation
import MultipeerConnectivity

final class HostPeerService: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, @unchecked Sendable {
    private let serviceType = "standup-timer"
    private let myPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?

    @MainActor var onCommandReceived: ((TimerCommand) -> Void)?
    @MainActor var connectedPeers: Int = 0

    override init() {
        let pid = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
        myPeerID = pid
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        session.delegate = self
    }

    @MainActor func start() {
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    @MainActor func stop() {
        advertiser?.stopAdvertisingPeer()
        session.disconnect()
    }

    func sendStatus(_ status: TimerStatus) {
        guard !session.connectedPeers.isEmpty,
              let data = PeerMessage.fromStatus(status).encode() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: - MCNearbyServiceAdvertiserDelegate

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}

    // MARK: - MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let count = session.connectedPeers.count
        Task { @MainActor in connectedPeers = count }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = PeerMessage.decode(from: data),
              message.kind == .command,
              let command = message.command else { return }
        Task { @MainActor in onCommandReceived?(command) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
