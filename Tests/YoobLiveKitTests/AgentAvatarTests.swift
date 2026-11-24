import XCTest
import Yoob
@testable import YoobLiveKit

final class AgentAvatarTests: XCTestCase {
    func testAnnouncementReadsCharacterAndVersion() throws {
        let attributes = ["yoob.avatar.character": "astrid", "yoob.avatar.version": "2026.11.15.1"]
        let found = try XCTUnwrap(YoobAgentAvatar.announcement(identity: "agent-1", attributes: attributes, wanted: nil))
        XCTAssertEqual(found.0, "astrid")
        XCTAssertEqual(found.1, "2026.11.15.1")
        let unversioned = try XCTUnwrap(YoobAgentAvatar.announcement(identity: "agent-1",
                                                                     attributes: ["yoob.avatar.character": "astrid"], wanted: nil))
        XCTAssertNil(unversioned.1)
    }

    func testNoAnnouncementOrAnotherAgent() {
        XCTAssertNil(YoobAgentAvatar.announcement(identity: "agent-1", attributes: [:], wanted: nil))
        XCTAssertNil(YoobAgentAvatar.announcement(identity: "agent-1", attributes: ["yoob.avatar.character": ""], wanted: nil))
        XCTAssertNil(YoobAgentAvatar.announcement(identity: "agent-1", attributes: ["yoob.avatar.character": "astrid"],
                                                  wanted: "agent-2"))
    }

    func testRefusalsKeepYoobsReason() {
        XCTAssertEqual(YoobAgentAvatar.refused(message: "Yoob session refused", data: #"{"code":"payment_required"}"#), .outOfCredit)
        XCTAssertEqual(YoobAgentAvatar.refused(message: "Yoob session refused",
                                               data: #"{"error":"Invalid or revoked API key.","code":"unauthorized"}"#), .unauthorized)
        XCTAssertEqual(YoobAgentAvatar.refused(message: "not allowed", data: nil), .unauthorized)
        if case .network = YoobAgentAvatar.refused(message: "Yoob could not be reached", data: nil) {} else {
            XCTFail("an unreachable Yoob is a network error")
        }
    }

    func testParsesTheSessionAndRejectsOthers() throws {
        let credentials = try YoobAgentAvatar.parse(#"{"session_token":"st","download_token":"dt","heartbeat_seconds":15}"#)
        XCTAssertEqual(credentials.sessionToken, "st")
        XCTAssertThrowsError(try YoobAgentAvatar.parse("not json"))
    }
}
