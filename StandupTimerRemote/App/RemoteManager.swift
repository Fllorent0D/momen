import Foundation
import MultipeerConnectivity
import UIKit

final class RemoteManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, @unchecked Sendable, Observable {
    private let serviceType = "standup-timer"
    private let myPeerID: MCPeerID
    private let session: MCSession
    private var browser: MCNearbyServiceBrowser?

    @MainActor var status: TimerStatus?
    @MainActor var isConnected = false
    @MainActor var hostName: String?

    override init() {
        let pid = MCPeerID(displayName: UIDevice.current.name)
        myPeerID = pid
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        session.delegate = self
        let b = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        b.delegate = self
        b.startBrowsingForPeers()
        browser = b
    }

    func sendCommand(_ command: TimerCommand) {
        guard !session.connectedPeers.isEmpty,
              let data = PeerMessage.fromCommand(command).encode() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: - MCNearbyServiceBrowserDelegate

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}

    // MARK: - MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let connected = !session.connectedPeers.isEmpty
        let name = session.connectedPeers.first?.displayName
        Task { @MainActor in
            isConnected = connected
            hostName = name
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = PeerMessage.decode(from: data),
              message.kind == .status,
              let newStatus = message.status else { return }
        Task { @MainActor in
            status = newStatus
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
