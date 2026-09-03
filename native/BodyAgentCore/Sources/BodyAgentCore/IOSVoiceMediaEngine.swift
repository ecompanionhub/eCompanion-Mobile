import Foundation

#if os(iOS)
@preconcurrency import AVFAudio

@MainActor
public final class IOSVoiceMediaEngine {
    public typealias CaptureHandler = @Sendable (VoiceCapturedAudioFrame) -> Void

    private let engine: AVAudioEngine
    private let player: AVAudioPlayerNode
    private var captureHandler: CaptureHandler?
    private var negotiatedFormat: VoiceMediaFormat?
    private var running = false
    private var tapInstalled = false

    public init() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        self.engine = engine
        self.player = player
    }

    @discardableResult
    public func start(captureHandler: CaptureHandler? = nil) throws -> VoiceMediaFormat {
        if running, let negotiatedFormat {
            self.captureHandler = captureHandler
            return negotiatedFormat
        }

        let input = engine.inputNode
        try input.setVoiceProcessingEnabled(true)

        let inputFormat = input.outputFormat(forBus: 0)
        guard
            inputFormat.sampleRate > 0,
            inputFormat.channelCount > 0,
            inputFormat.commonFormat == .pcmFormatFloat32
        else {
            throw VoiceMediaError.invalidFormat
        }

        let sampleRate = Int(inputFormat.sampleRate.rounded())
        let preferredFrames = max(1, Int((inputFormat.sampleRate * 0.02).rounded()))
        let format = VoiceMediaFormat(
            sampleRate: sampleRate,
            channelCount: 1,
            framesPerPacket: preferredFrames
        )
        guard let playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw VoiceMediaError.invalidFormat
        }

        if engine.outputConnectionPoints(for: player, outputBus: 0).isEmpty {
            engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)
        }

        self.captureHandler = captureHandler
        self.negotiatedFormat = format

        let callback = captureHandler
        input.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(preferredFrames),
            format: inputFormat
        ) { buffer, _ in
            guard let callback else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            guard frameLength > 0, channelCount > 0, let channelData = buffer.floatChannelData else { return }

            var mono = [Float](repeating: 0, count: frameLength)
            let divisor = Float(channelCount)
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for index in 0..<frameLength {
                    mono[index] += samples[index] / divisor
                }
            }

            let payload = VoicePCM16.encodeMono(samples: mono)
            let capturedFormat = VoiceMediaFormat(
                sampleRate: sampleRate,
                channelCount: 1,
                framesPerPacket: frameLength
            )
            callback(
                VoiceCapturedAudioFrame(
                    format: capturedFormat,
                    capturedAtMilliseconds: Int64((Date().timeIntervalSince1970 * 1_000).rounded()),
                    voiceActivity: VoicePCM16.hasVoiceActivity(samples: mono),
                    payload: payload
                )
            )
        }
        tapInstalled = true

        engine.prepare()
        try engine.start()
        player.play()
        running = true
        return format
    }

    public func enqueuePlayback(_ frame: VoiceTransportAudioFrame) throws {
        guard running, let negotiatedFormat else {
            throw VoiceMediaError.callNotReady
        }
        guard
            frame.format.encoding == .pcm16LittleEndian,
            frame.format.channelCount == 1,
            frame.format.sampleRate == negotiatedFormat.sampleRate
        else {
            throw VoiceMediaError.invalidFormat
        }

        let samples = try VoicePCM16.decodeMono(frame.payload)
        guard samples.count == frame.format.framesPerPacket else {
            throw VoiceMediaError.invalidPCMByteCount
        }
        guard let playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(frame.format.sampleRate),
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ), let channel = buffer.floatChannelData?[0] else {
            throw VoiceMediaError.invalidFormat
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for index in samples.indices {
            channel[index] = samples[index]
        }
        player.scheduleBuffer(buffer)
        if !player.isPlaying {
            player.play()
        }
    }

    public func stop() {
        guard running || tapInstalled else { return }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        player.stop()
        engine.stop()
        captureHandler = nil
        negotiatedFormat = nil
        running = false
    }

    public func isRunning() -> Bool {
        running
    }

    public func currentFormat() -> VoiceMediaFormat? {
        negotiatedFormat
    }
}
#endif
