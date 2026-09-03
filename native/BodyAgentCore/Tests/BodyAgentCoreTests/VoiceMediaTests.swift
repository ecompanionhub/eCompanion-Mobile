import XCTest
@testable import BodyAgentCore

final class VoiceMediaTests: XCTestCase {
    func testPCM16RoundTripAndClamping() throws {
        let source: [Float] = [-2.0, -1.0, -0.5, 0, 0.5, 1.0, 2.0]
        let encoded = VoicePCM16.encodeMono(samples: source)
        let decoded = try VoicePCM16.decodeMono(encoded)

        XCTAssertEqual(encoded.count, source.count * MemoryLayout<Int16>.size)
        XCTAssertEqual(decoded.count, source.count)
        XCTAssertEqual(decoded[0], -1.0, accuracy: 0.0001)
        XCTAssertEqual(decoded[1], -1.0, accuracy: 0.0001)
        XCTAssertEqual(decoded[2], -0.5, accuracy: 0.001)
        XCTAssertEqual(decoded[3], 0, accuracy: 0.0001)
        XCTAssertEqual(decoded[4], 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded[5], 1.0, accuracy: 0.0001)
        XCTAssertEqual(decoded[6], 1.0, accuracy: 0.0001)
    }

    func testPCM16RejectsOddByteCount() {
        XCTAssertThrowsError(try VoicePCM16.decodeMono(Data([0x00]))) { error in
            XCTAssertEqual(error as? VoiceMediaError, .invalidPCMByteCount)
        }
    }

    func testVoiceActivityUsesRMSNotSingleSamplePeak() {
        XCTAssertFalse(VoicePCM16.hasVoiceActivity(samples: Array(repeating: 0.001, count: 320)))
        XCTAssertTrue(VoicePCM16.hasVoiceActivity(samples: Array(repeating: 0.05, count: 320)))
    }

    func testMediaFormatByteAccounting() {
        let format = VoiceMediaFormat(sampleRate: 48_000, channelCount: 1, framesPerPacket: 960)
        XCTAssertEqual(format.bytesPerFrame, 2)
        XCTAssertEqual(format.expectedPacketBytes, 1_920)
    }

    func testSequencerBindsCapturedPCMToCanonicalCallSession() async throws {
        let sessionID = UUID()
        let session = try VoiceCallSession(
            conversationID: "conversation-1",
            sessionID: sessionID,
            streamID: "stream-1"
        )
        _ = try await session.start()
        _ = try await session.connected()
        let sequencer = VoiceMediaSequencer(session: session)
        let format = VoiceMediaFormat(sampleRate: 48_000, framesPerPacket: 4)
        let captured = VoiceCapturedAudioFrame(
            format: format,
            capturedAtMilliseconds: 123_456,
            voiceActivity: true,
            payload: VoicePCM16.encodeMono(samples: [0.1, 0.2, 0.3, 0.4])
        )

        let first = try await sequencer.transportFrame(from: captured)
        let second = try await sequencer.transportFrame(from: captured)

        XCTAssertEqual(first.metadata.sessionID, sessionID)
        XCTAssertEqual(first.metadata.conversationID, "conversation-1")
        XCTAssertEqual(first.metadata.streamID, "stream-1")
        XCTAssertEqual(first.metadata.sequence, 0)
        XCTAssertEqual(second.metadata.sequence, 1)
        XCTAssertEqual(first.metadata.transportGeneration, 1)
        XCTAssertEqual(first.metadata.capturedAtMilliseconds, 123_456)
        XCTAssertTrue(first.metadata.voiceActivity)
        XCTAssertEqual(first.metadata.byteCount, captured.payload.count)
        XCTAssertEqual(first.payload, captured.payload)
        XCTAssertEqual(first.format, format)
    }

    func testBoundedTransportDropsOldestFrameInsteadOfGrowingUnbounded() async throws {
        let sink = try BufferedVoiceMediaTransportSink(capacity: 2)
        let session = try VoiceCallSession(conversationID: "conversation-2", streamID: "stream-2")
        _ = try await session.start()
        _ = try await session.connected()
        let sequencer = VoiceMediaSequencer(session: session)
        let format = VoiceMediaFormat(sampleRate: 48_000, framesPerPacket: 2)

        for timestamp in 1...3 {
            let captured = VoiceCapturedAudioFrame(
                format: format,
                capturedAtMilliseconds: Int64(timestamp),
                voiceActivity: true,
                payload: VoicePCM16.encodeMono(samples: [0.1, 0.2])
            )
            try await sink.send(try await sequencer.transportFrame(from: captured))
        }

        let snapshot = await sink.snapshot()
        XCTAssertEqual(snapshot.buffered, 2)
        XCTAssertEqual(snapshot.dropped, 1)
        let frames = await sink.drain()
        XCTAssertEqual(frames.map(\.metadata.sequence), [1, 2])
    }

    func testCapturePipelineSequencesBeforeTransportSink() async throws {
        let sink = try BufferedVoiceMediaTransportSink(capacity: 4)
        let session = try VoiceCallSession(conversationID: "conversation-3", streamID: "stream-3")
        _ = try await session.start()
        _ = try await session.connected()
        let pipeline = VoiceMediaCapturePipeline(session: session, sink: sink)
        let format = VoiceMediaFormat(sampleRate: 48_000, framesPerPacket: 2)
        let captured = VoiceCapturedAudioFrame(
            format: format,
            capturedAtMilliseconds: 9_999,
            voiceActivity: false,
            payload: VoicePCM16.encodeMono(samples: [0, 0])
        )

        try await pipeline.accept(captured)

        let frames = await sink.drain()
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].metadata.sequence, 0)
        XCTAssertEqual(frames[0].metadata.capturedAtMilliseconds, 9_999)
        XCTAssertFalse(frames[0].metadata.voiceActivity)
        XCTAssertEqual(frames[0].payload, captured.payload)
    }

    func testTransportBufferRejectsZeroCapacity() {
        XCTAssertThrowsError(try BufferedVoiceMediaTransportSink(capacity: 0)) { error in
            XCTAssertEqual(error as? VoiceMediaError, .invalidBufferCapacity)
        }
    }
}
