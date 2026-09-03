import Foundation

public enum VoiceMediaEncoding: String, Codable, Sendable, Equatable {
    case pcm16LittleEndian = "pcm_s16le"
}

public struct VoiceMediaFormat: Codable, Sendable, Equatable {
    public let sampleRate: Int
    public let channelCount: Int
    public let framesPerPacket: Int
    public let encoding: VoiceMediaEncoding

    public init(
        sampleRate: Int,
        channelCount: Int = 1,
        framesPerPacket: Int,
        encoding: VoiceMediaEncoding = .pcm16LittleEndian
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.framesPerPacket = framesPerPacket
        self.encoding = encoding
    }

    public var bytesPerFrame: Int {
        channelCount * MemoryLayout<Int16>.size
    }

    public var expectedPacketBytes: Int {
        framesPerPacket * bytesPerFrame
    }
}

public struct VoiceCapturedAudioFrame: Sendable, Equatable {
    public let format: VoiceMediaFormat
    public let capturedAtMilliseconds: Int64
    public let voiceActivity: Bool
    public let payload: Data

    public init(
        format: VoiceMediaFormat,
        capturedAtMilliseconds: Int64,
        voiceActivity: Bool,
        payload: Data
    ) {
        self.format = format
        self.capturedAtMilliseconds = capturedAtMilliseconds
        self.voiceActivity = voiceActivity
        self.payload = payload
    }
}

public struct VoiceTransportAudioFrame: Sendable, Equatable {
    public let metadata: VoiceAudioChunkMetadata
    public let format: VoiceMediaFormat
    public let payload: Data

    public init(
        metadata: VoiceAudioChunkMetadata,
        format: VoiceMediaFormat,
        payload: Data
    ) {
        self.metadata = metadata
        self.format = format
        self.payload = payload
    }
}

public enum VoiceMediaError: Error, Sendable, Equatable {
    case invalidFormat
    case invalidPCMByteCount
    case callNotReady
    case invalidBufferCapacity
}

public enum VoicePCM16 {
    public static func encodeMono(samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            let bounded = max(-1.0, min(1.0, sample))
            let scaled: Int16
            if bounded <= -1.0 {
                scaled = Int16.min
            } else {
                scaled = Int16((bounded * Float(Int16.max)).rounded())
            }
            var littleEndian = scaled.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }

    public static func decodeMono(_ data: Data) throws -> [Float] {
        guard data.count.isMultiple(of: MemoryLayout<Int16>.size) else {
            throw VoiceMediaError.invalidPCMByteCount
        }

        return data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var samples: [Float] = []
            samples.reserveCapacity(data.count / MemoryLayout<Int16>.size)
            var index = 0
            while index < bytes.count {
                let bits = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                let signed = Int16(bitPattern: bits)
                let value: Float
                if signed == Int16.min {
                    value = -1.0
                } else {
                    value = Float(signed) / Float(Int16.max)
                }
                samples.append(value)
                index += 2
            }
            return samples
        }
    }

    public static func hasVoiceActivity(samples: [Float], threshold: Float = 0.015) -> Bool {
        guard !samples.isEmpty else { return false }
        let energy = samples.reduce(Float.zero) { partial, sample in
            partial + (sample * sample)
        } / Float(samples.count)
        return sqrt(energy) >= threshold
    }
}

public actor VoiceMediaSequencer {
    private let session: VoiceCallSession

    public init(session: VoiceCallSession) {
        self.session = session
    }

    public func transportFrame(from captured: VoiceCapturedAudioFrame) async throws -> VoiceTransportAudioFrame {
        let metadata = try await session.nextAudioChunk(
            byteCount: captured.payload.count,
            voiceActivity: captured.voiceActivity,
            capturedAtMilliseconds: captured.capturedAtMilliseconds
        )
        return VoiceTransportAudioFrame(
            metadata: metadata,
            format: captured.format,
            payload: captured.payload
        )
    }
}

public protocol VoiceMediaTransportSink: Sendable {
    func send(_ frame: VoiceTransportAudioFrame) async throws
}

public actor BufferedVoiceMediaTransportSink: VoiceMediaTransportSink {
    private let capacity: Int
    private var frames: [VoiceTransportAudioFrame] = []
    private var droppedFrameCount = 0

    public init(capacity: Int = 64) throws {
        guard capacity > 0 else { throw VoiceMediaError.invalidBufferCapacity }
        self.capacity = capacity
    }

    public func send(_ frame: VoiceTransportAudioFrame) async throws {
        if frames.count == capacity {
            frames.removeFirst()
            droppedFrameCount += 1
        }
        frames.append(frame)
    }

    public func drain() -> [VoiceTransportAudioFrame] {
        defer { frames.removeAll(keepingCapacity: true) }
        return frames
    }

    public func snapshot() -> (buffered: Int, dropped: Int) {
        (frames.count, droppedFrameCount)
    }
}

public actor VoiceMediaCapturePipeline {
    private let sequencer: VoiceMediaSequencer
    private let sink: any VoiceMediaTransportSink

    public init(session: VoiceCallSession, sink: any VoiceMediaTransportSink) {
        self.sequencer = VoiceMediaSequencer(session: session)
        self.sink = sink
    }

    public func accept(_ captured: VoiceCapturedAudioFrame) async throws {
        let frame = try await sequencer.transportFrame(from: captured)
        try await sink.send(frame)
    }
}
