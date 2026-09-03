import Foundation

public struct VoiceAudioSessionPolicy: Sendable, Equatable {
    public let sampleRate: Double
    public let preferredIOBufferDuration: TimeInterval
    public let supportsBackgroundCallAudio: Bool
    public let requiresMicrophonePermission: Bool

    public init(
        sampleRate: Double = 48_000,
        preferredIOBufferDuration: TimeInterval = 0.02,
        supportsBackgroundCallAudio: Bool = true,
        requiresMicrophonePermission: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.preferredIOBufferDuration = preferredIOBufferDuration
        self.supportsBackgroundCallAudio = supportsBackgroundCallAudio
        self.requiresMicrophonePermission = requiresMicrophonePermission
    }

    public static let voiceCall = VoiceAudioSessionPolicy()
}

#if os(iOS)
@preconcurrency import AVFAudio

public actor IOSVoiceAudioSession {
    private let policy: VoiceAudioSessionPolicy
    private let audioSession: AVAudioSession
    private var active = false

    public init(policy: VoiceAudioSessionPolicy = .voiceCall) {
        self.policy = policy
        self.audioSession = AVAudioSession.sharedInstance()
    }

    public func activate() throws {
        if active { return }
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .defaultToSpeaker]
        )
        try audioSession.setPreferredSampleRate(policy.sampleRate)
        try audioSession.setPreferredIOBufferDuration(policy.preferredIOBufferDuration)
        try audioSession.setActive(true)
        active = true
    }

    public func deactivate() throws {
        if !active { return }
        try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        active = false
    }

    public func isActive() -> Bool {
        active
    }

    public func currentRouteDescription() -> String {
        let inputs = audioSession.currentRoute.inputs.map(\.portName).joined(separator: ",")
        let outputs = audioSession.currentRoute.outputs.map(\.portName).joined(separator: ",")
        return "in=\(inputs);out=\(outputs)"
    }
}
#endif
