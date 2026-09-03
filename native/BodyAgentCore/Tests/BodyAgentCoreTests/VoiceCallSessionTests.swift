import XCTest
@testable import BodyAgentCore

final class VoiceCallSessionTests: XCTestCase {
    func testReconnectPreservesCanonicalConversationAndSequence() async throws {
        let sessionID = UUID()
        let call = try VoiceCallSession(
            conversationID: "companion:lola:owner:call",
            sessionID: sessionID,
            streamID: "owner-mic"
        )

        _ = try await call.start()
        _ = try await call.connected()
        let first = try await call.nextAudioChunk(byteCount: 640, voiceActivity: true, capturedAtMilliseconds: 1000)
        let second = try await call.nextAudioChunk(byteCount: 640, voiceActivity: true, capturedAtMilliseconds: 1020)
        try await call.acknowledge(sequence: first.sequence)

        let disconnected = try await call.transportLost()
        XCTAssertEqual(disconnected.state, .reconnecting)
        XCTAssertEqual(disconnected.transportGeneration, 1)
        XCTAssertEqual(disconnected.conversationID, "companion:lola:owner:call")

        let resumed = try await call.reconnected(lastAcknowledgedSequence: second.sequence)
        XCTAssertEqual(resumed.state, .active)
        XCTAssertEqual(resumed.sessionID, sessionID)
        XCTAssertEqual(resumed.conversationID, "companion:lola:owner:call")
        XCTAssertEqual(resumed.streamID, "owner-mic")
        XCTAssertEqual(resumed.transportGeneration, 2)
        XCTAssertEqual(resumed.resumeCount, 1)
        XCTAssertEqual(resumed.lastAcknowledgedSequence, 1)

        let third = try await call.nextAudioChunk(byteCount: 640, voiceActivity: false, capturedAtMilliseconds: 1040)
        XCTAssertEqual(third.sequence, 2)
        XCTAssertEqual(third.transportGeneration, 2)
        XCTAssertEqual(third.conversationID, first.conversationID)
    }

    func testInterruptionDoesNotCreateAnotherCallIdentity() async throws {
        let sessionID = UUID()
        let call = try VoiceCallSession(conversationID: "conversation-1", sessionID: sessionID, streamID: "stream-1")
        _ = try await call.start()
        _ = try await call.connected()

        let interrupted = try await call.interrupt()
        XCTAssertEqual(interrupted.state, .interrupted)
        XCTAssertEqual(interrupted.sessionID, sessionID)

        await XCTAssertThrowsErrorAsync(try await call.nextAudioChunk(byteCount: 320, voiceActivity: true)) { error in
            XCTAssertEqual(error as? VoiceCallSessionError, .callNotActive)
        }

        let resumed = try await call.resumeAfterInterruption()
        XCTAssertEqual(resumed.state, .active)
        XCTAssertEqual(resumed.sessionID, sessionID)
        XCTAssertEqual(resumed.transportGeneration, 1)
    }

    func testAcknowledgementCannotInventUnsentAudio() async throws {
        let call = try VoiceCallSession(conversationID: "conversation-2")
        _ = try await call.start()
        _ = try await call.connected()
        _ = try await call.nextAudioChunk(byteCount: 320, voiceActivity: true)

        await XCTAssertThrowsErrorAsync(try await call.acknowledge(sequence: 1)) { error in
            XCTAssertEqual(error as? VoiceCallSessionError, .invalidAcknowledgement)
        }

        try await call.acknowledge(sequence: 0)
        let snapshot = await call.snapshot()
        XCTAssertEqual(snapshot.lastAcknowledgedSequence, 0)
    }

    func testEndIsIdempotentAndBlocksFurtherAudio() async throws {
        let call = try VoiceCallSession(conversationID: "conversation-3")
        _ = try await call.start()
        _ = try await call.connected()
        let ended = try await call.end()
        XCTAssertEqual(ended.state, .ended)
        let endedAgain = try await call.end()
        XCTAssertEqual(endedAgain.state, .ended)

        await XCTAssertThrowsErrorAsync(try await call.nextAudioChunk(byteCount: 320, voiceActivity: true)) { error in
            XCTAssertEqual(error as? VoiceCallSessionError, .callEnded)
        }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        verify(error)
    }
}
