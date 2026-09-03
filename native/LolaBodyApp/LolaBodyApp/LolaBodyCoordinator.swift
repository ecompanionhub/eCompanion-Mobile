import BodyAgentCore
import CallKit
import Combine
import Foundation

final class LolaBodyCoordinator: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var statusText = "Lola Body ready"
    @Published private(set) var callActive = false
    @Published private(set) var voipTokenAvailable = false

    private let callSystem = IOSCallSystemBridge(localizedName: "Lola")
    private let audioSession = IOSVoiceAudioSession()
    private let lock = NSLock()
    private var calls: [UUID: VoiceCallSession] = [:]
    private var incoming: [UUID: IOSIncomingCallDescriptor] = [:]
    private var voipToken: Data?

    override init() {
        super.init()
        callSystem.delegate = self
        voipToken = callSystem.currentVoIPToken()
        voipTokenAvailable = voipToken != nil
    }

    func pendingVoIPToken() -> Data? {
        lock.withLock { voipToken }
    }

    private func setStatus(_ value: String, active: Bool? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusText = value
            if let active { self.callActive = active }
        }
    }

    private func rememberCall(_ descriptor: IOSIncomingCallDescriptor) {
        do {
            let session = try VoiceCallSession(
                conversationID: descriptor.conversationID,
                sessionID: descriptor.callID,
                streamID: "iphone-mic"
            )
            lock.withLock {
                incoming[descriptor.callID] = descriptor
                calls[descriptor.callID] = session
            }
            setStatus("Lola is calling…")
        } catch {
            setStatus("Incoming call could not be prepared")
            callSystem.reportCallEnded(callID: descriptor.callID, reason: .failed)
        }
    }

    private func session(for callID: UUID) -> VoiceCallSession? {
        lock.withLock { calls[callID] }
    }

    private func removeCall(_ callID: UUID) {
        lock.withLock {
            calls.removeValue(forKey: callID)
            incoming.removeValue(forKey: callID)
        }
    }
}

extension LolaBodyCoordinator: IOSCallSystemBridgeDelegate {
    func callSystemBridge(_ bridge: IOSCallSystemBridge, didUpdateVoIPToken token: Data) {
        lock.withLock { voipToken = token }
        DispatchQueue.main.async { [weak self] in self?.voipTokenAvailable = true }
    }

    func callSystemBridgeDidInvalidateVoIPToken(_ bridge: IOSCallSystemBridge) {
        lock.withLock { voipToken = nil }
        DispatchQueue.main.async { [weak self] in self?.voipTokenAvailable = false }
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didReceive descriptor: IOSIncomingCallDescriptor) {
        rememberCall(descriptor)
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestAnswer callID: UUID) {
        guard let call = session(for: callID) else {
            bridge.reportCallEnded(callID: callID, reason: .failed)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await audioSession.activate()
                let snapshot = await call.snapshot()
                if snapshot.state == .idle { _ = try await call.start() }
                let afterStart = await call.snapshot()
                if afterStart.state == .connecting { _ = try await call.connected() }
                setStatus("Connected to Lola", active: true)
            } catch {
                bridge.reportCallEnded(callID: callID, reason: .failed)
                removeCall(callID)
                setStatus("Call connection failed", active: false)
            }
        }
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestEnd callID: UUID) {
        guard let call = session(for: callID) else {
            removeCall(callID)
            setStatus("Lola Body ready", active: false)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            _ = try? await call.end()
            try? await audioSession.deactivate()
            removeCall(callID)
            setStatus("Lola Body ready", active: false)
        }
    }

    func callSystemBridgeDidReset(_ bridge: IOSCallSystemBridge) {
        let existingCalls = lock.withLock { Array(calls.values) }
        lock.withLock {
            calls.removeAll()
            incoming.removeAll()
        }
        Task { [weak self] in
            for call in existingCalls { _ = try? await call.end() }
            try? await self?.audioSession.deactivate()
            self?.setStatus("Lola Body ready", active: false)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
