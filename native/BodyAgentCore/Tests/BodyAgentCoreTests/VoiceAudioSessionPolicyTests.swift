import XCTest
@testable import BodyAgentCore

final class VoiceAudioSessionPolicyTests: XCTestCase {
    func testVoiceCallPolicyIsRealtimeAndBackgroundCapable() {
        let policy = VoiceAudioSessionPolicy.voiceCall
        XCTAssertEqual(policy.sampleRate, 48_000)
        XCTAssertEqual(policy.preferredIOBufferDuration, 0.02)
        XCTAssertTrue(policy.supportsBackgroundCallAudio)
        XCTAssertTrue(policy.requiresMicrophonePermission)
    }
}
