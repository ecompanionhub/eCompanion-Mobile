import Foundation

public enum VoiceCallLifecycleState: String, Codable, Sendable, Equatable {
    case idle
    case connecting
    case active
    case reconnecting
    case interrupted
    case ending
    case ended
}

public struct VoiceAudioChunkMetadata: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let conversationID: String
    public let streamID: String
    public let sequence: Int
    public let transportGeneration: Int
    public let capturedAtMilliseconds: Int64?
    public let voiceActivity: Bool
    public let byteCount: Int

    public init(
        sessionID: UUID,
        conversationID: String,
        streamID: String,
        sequence: Int,
        transportGeneration: Int,
        capturedAtMilliseconds: Int64? = nil,
        voiceActivity: Bool,
        byteCount: Int
    ) {
        self.sessionID = sessionID
        self.conversationID = conversationID
        self.streamID = streamID
        self.sequence = sequence
        self.transportGeneration = transportGeneration
        self.capturedAtMilliseconds = capturedAtMilliseconds
        self.voiceActivity = voiceActivity
        self.byteCount = byteCount
    }
}

public struct VoiceCallSnapshot: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let conversationID: String
    public let streamID: String
    public let state: VoiceCallLifecycleState
    public let transportGeneration: Int
    public let resumeCount: Int
    public let nextSequence: Int
    public let lastSentSequence: Int?
    public let lastAcknowledgedSequence: Int?

    public init(
        sessionID: UUID,
        conversationID: String,
        streamID: String,
        state: VoiceCallLifecycleState,
        transportGeneration: Int,
        resumeCount: Int,
        nextSequence: Int,
        lastSentSequence: Int?,
        lastAcknowledgedSequence: Int?
    ) {
        self.sessionID = sessionID
        self.conversationID = conversationID
        self.streamID = streamID
        self.state = state
        self.transportGeneration = transportGeneration
        self.resumeCount = resumeCount
        self.nextSequence = nextSequence
        self.lastSentSequence = lastSentSequence
        self.lastAcknowledgedSequence = lastAcknowledgedSequence
    }
}

public enum VoiceCallSessionError: Error, Sendable, Equatable {
    case invalidConversationID
    case invalidStreamID
    case invalidTransition(from: VoiceCallLifecycleState, to: VoiceCallLifecycleState)
    case callNotActive
    case callEnded
    case invalidByteCount
    case invalidAcknowledgement
}

public actor VoiceCallSession {
    private let sessionID: UUID
    private let conversationID: String
    private let streamID: String
    private var state: VoiceCallLifecycleState = .idle
    private var transportGeneration = 1
    private var resumeCount = 0
    private var nextSequence = 0
    private var lastSentSequence: Int?
    private var lastAcknowledgedSequence: Int?

    public init(
        conversationID: String,
        sessionID: UUID = UUID(),
        streamID: String = UUID().uuidString.lowercased()
    ) throws {
        let normalizedConversationID = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStreamID = streamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedConversationID.isEmpty, normalizedConversationID.count <= 200 else {
            throw VoiceCallSessionError.invalidConversationID
        }
        guard !normalizedStreamID.isEmpty, normalizedStreamID.count <= 200 else {
            throw VoiceCallSessionError.invalidStreamID
        }
        self.sessionID = sessionID
        self.conversationID = normalizedConversationID
        self.streamID = normalizedStreamID
    }

    public func snapshot() -> VoiceCallSnapshot {
        VoiceCallSnapshot(
            sessionID: sessionID,
            conversationID: conversationID,
            streamID: streamID,
            state: state,
            transportGeneration: transportGeneration,
            resumeCount: resumeCount,
            nextSequence: nextSequence,
            lastSentSequence: lastSentSequence,
            lastAcknowledgedSequence: lastAcknowledgedSequence
        )
    }

    @discardableResult
    public func start() throws -> VoiceCallSnapshot {
        try transition(from: [.idle], to: .connecting)
        return snapshot()
    }

    @discardableResult
    public func connected() throws -> VoiceCallSnapshot {
        try transition(from: [.connecting], to: .active)
        return snapshot()
    }

    @discardableResult
    public func transportLost() throws -> VoiceCallSnapshot {
        if state == .ended { throw VoiceCallSessionError.callEnded }
        if state == .reconnecting { return snapshot() }
        try transition(from: [.connecting, .active, .interrupted], to: .reconnecting)
        return snapshot()
    }

    @discardableResult
    public func reconnected(lastAcknowledgedSequence recoveredSequence: Int? = nil) throws -> VoiceCallSnapshot {
        if state == .ended { throw VoiceCallSessionError.callEnded }
        guard state == .reconnecting else {
            throw VoiceCallSessionError.invalidTransition(from: state, to: .active)
        }
        if let recoveredSequence {
            try acknowledge(sequence: recoveredSequence)
        }
        transportGeneration += 1
        resumeCount += 1
        state = .active
        return snapshot()
    }

    @discardableResult
    public func interrupt() throws -> VoiceCallSnapshot {
        if state == .ended { throw VoiceCallSessionError.callEnded }
        if state == .interrupted { return snapshot() }
        try transition(from: [.active], to: .interrupted)
        return snapshot()
    }

    @discardableResult
    public func resumeAfterInterruption() throws -> VoiceCallSnapshot {
        if state == .ended { throw VoiceCallSessionError.callEnded }
        try transition(from: [.interrupted], to: .active)
        return snapshot()
    }

    public func nextAudioChunk(
        byteCount: Int,
        voiceActivity: Bool,
        capturedAtMilliseconds: Int64? = nil
    ) throws -> VoiceAudioChunkMetadata {
        if state == .ended { throw VoiceCallSessionError.callEnded }
        guard state == .active else { throw VoiceCallSessionError.callNotActive }
        guard byteCount >= 0 else { throw VoiceCallSessionError.invalidByteCount }
        let sequence = nextSequence
        nextSequence += 1
        lastSentSequence = sequence
        return VoiceAudioChunkMetadata(
            sessionID: sessionID,
            conversationID: conversationID,
            streamID: streamID,
            sequence: sequence,
            transportGeneration: transportGeneration,
            capturedAtMilliseconds: capturedAtMilliseconds,
            voiceActivity: voiceActivity,
            byteCount: byteCount
        )
    }

    public func acknowledge(sequence: Int) throws {
        guard sequence >= 0, let lastSentSequence, sequence <= lastSentSequence else {
            throw VoiceCallSessionError.invalidAcknowledgement
        }
        if let current = lastAcknowledgedSequence, sequence < current {
            throw VoiceCallSessionError.invalidAcknowledgement
        }
        lastAcknowledgedSequence = sequence
    }

    @discardableResult
    public func beginEnding() throws -> VoiceCallSnapshot {
        if state == .ended { return snapshot() }
        if state == .ending { return snapshot() }
        try transition(from: [.connecting, .active, .reconnecting, .interrupted], to: .ending)
        return snapshot()
    }

    @discardableResult
    public func end() throws -> VoiceCallSnapshot {
        if state == .ended { return snapshot() }
        if state != .ending {
            _ = try beginEnding()
        }
        state = .ended
        return snapshot()
    }

    private func transition(from allowed: Set<VoiceCallLifecycleState>, to next: VoiceCallLifecycleState) throws {
        guard allowed.contains(state) else {
            throw VoiceCallSessionError.invalidTransition(from: state, to: next)
        }
        state = next
    }
}
