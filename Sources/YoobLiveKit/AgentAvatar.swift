import Foundation
import LiveKit
import Yoob

/// What a LiveKit agent running `livekit-plugins-yoob`'s `yoob.AvatarSession` announces: its character, and a way to
/// open Yoob sessions through it, so the app needs no Yoob session route of its own (the Yoob key stays with the agent).
///
/// ```swift
/// try await room.connect(url: url, token: token)
/// let agent = try await YoobAgentAvatar.wait(in: room)
/// let avatar = YoobAvatar(agent.source, version: agent.version)
/// let session = YoobLiveKitSession(avatar: avatar, room: room)
/// try await session.start()
/// ```
public struct YoobAgentAvatar: Sendable {
    public let character: String
    /// The character version the agent pinned, if any.
    public let version: String?
    public let agentIdentity: String
    /// Opens a Yoob session through the agent (the RPC `yoob.avatar.session`).
    public let credentials: @Sendable () async throws -> YoobCredentials

    /// The character from the Yoob CDN, with sessions opened through the agent.
    public var source: YoobSource { .cloud(character: character, credentials: credentials) }

    static let characterAttribute = "yoob.avatar.character"
    static let versionAttribute = "yoob.avatar.version"
    static let sessionMethod = "yoob.avatar.session"

    /// Waits for an agent in `room` that announces a Yoob character. `agentIdentity` limits it to one participant.
    /// Throws `YoobError.network` when none does within `timeout` seconds.
    @MainActor
    public static func wait(in room: Room, agentIdentity: String? = nil,
                            timeout: TimeInterval = 30) async throws -> YoobAgentAvatar {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for participant in room.remoteParticipants.values {
                guard let identity = participant.identity?.stringValue,
                      let found = announcement(identity: identity, attributes: participant.attributes,
                                               wanted: agentIdentity) else { continue }
                return YoobAgentAvatar(character: found.0, version: found.1, agentIdentity: identity) {
                    try await session(from: room, agentIdentity: identity)
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw YoobError.network("No agent in the room announced a Yoob character. Is the agent running yoob.AvatarSession?")
    }

    /// (character, version) when `attributes` announce a character and `identity` is the agent asked for.
    static func announcement(identity: String, attributes: [String: String], wanted: String?) -> (String, String?)? {
        if let wanted, identity != wanted { return nil }
        guard let character = attributes[characterAttribute], !character.isEmpty else { return nil }
        let version = attributes[versionAttribute].flatMap { $0.isEmpty ? nil : $0 }
        return (character, version)
    }

    static func session(from room: Room, agentIdentity: String) async throws -> YoobCredentials {
        let answer: String
        do {
            answer = try await room.localParticipant.performRpc(destinationIdentity: Participant.Identity(from: agentIdentity),
                                                                method: sessionMethod, payload: "")
        } catch let error as RpcError {
            throw refused(message: error.message, data: error.data)
        }
        return try parse(answer)
    }

    /// Yoob's reason, as the agent passed it on (the session API's error body).
    static func refused(message: String, data: String?) -> YoobError {
        let detail = "\(data ?? "") \(message)".lowercased()
        if ["payment_required", "out_of_credit", "out-of-credit", "insufficient"].contains(where: detail.contains) {
            return .outOfCredit
        }
        if ["unauthorized", "unauthorised", "forbidden", "not allowed", "invalid key", "invalid_key"].contains(where: detail.contains) {
            return .unauthorized
        }
        return .network("The agent couldn't open a Yoob session: \(message)")
    }

    static func parse(_ answer: String) throws -> YoobCredentials {
        do {
            return try JSONDecoder().decode(YoobCredentials.self, from: Data(answer.utf8))
        } catch {
            throw YoobError.unauthorized
        }
    }
}
