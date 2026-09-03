import UIKit
import BodyAgentCore

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate, IOSCallSystemBridgeDelegate {
    var window: UIWindow?

    private let voiceAudioSession = IOSVoiceAudioSession()
    private let voiceMediaEngine = IOSVoiceMediaEngine()
    private var callSystemBridge: IOSCallSystemBridge?
    private var incomingCalls: [UUID: IOSIncomingCallDescriptor] = [:]
    private var sessions: [UUID: VoiceCallSession] = [:]
    private var mediaPipelines: [UUID: VoiceMediaCapturePipeline] = [:]
    private var activeCallID: UUID?
    private var outboundVoiceFrames: BufferedVoiceMediaTransportSink?
    private weak var statusViewController: BodyStatusViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let bridge = IOSCallSystemBridge(localizedName: "eCompanion")
        bridge.delegate = self
        callSystemBridge = bridge

        do {
            outboundVoiceFrames = try BufferedVoiceMediaTransportSink(capacity: 64)
        } catch {
            assertionFailure("Voice media buffer configuration must be valid")
        }

        let status = BodyStatusViewController()
        statusViewController = status
        let navigation = UINavigationController(rootViewController: status)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window

        Task { [weak self] in
            do {
                try await self?.voiceAudioSession.configureForCallKit()
                self?.statusViewController?.setAudioConfigured(true)
            } catch {
                self?.statusViewController?.setFailure("Audio configuration failed")
            }
        }

        status.setVoIPRegistrationState(bridge.currentVoIPToken() == nil ? "registering" : "registered")
        return true
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didUpdateVoIPToken token: Data) {
        let tokenHex = token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenHex, forKey: "ecompanion.pending_voip_token")
        statusViewController?.setVoIPRegistrationState("registered")
    }

    func callSystemBridgeDidInvalidateVoIPToken(_ bridge: IOSCallSystemBridge) {
        UserDefaults.standard.removeObject(forKey: "ecompanion.pending_voip_token")
        statusViewController?.setVoIPRegistrationState("invalidated")
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didReceive descriptor: IOSIncomingCallDescriptor) {
        incomingCalls[descriptor.callID] = descriptor
        if sessions[descriptor.callID] == nil,
           let session = try? VoiceCallSession(
               conversationID: descriptor.conversationID,
               sessionID: descriptor.callID,
               streamID: descriptor.callID.uuidString.lowercased()
           ) {
            sessions[descriptor.callID] = session
            if let outboundVoiceFrames {
                mediaPipelines[descriptor.callID] = VoiceMediaCapturePipeline(
                    session: session,
                    sink: outboundVoiceFrames
                )
            }
        }
        statusViewController?.setCallState("incoming")
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestAnswer callID: UUID) {
        activeCallID = callID
        statusViewController?.setCallState("connecting")
        guard let session = sessions[callID] else { return }
        Task {
            let snapshot = await session.snapshot()
            if snapshot.state == .idle {
                _ = try? await session.start()
            }
        }
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestEnd callID: UUID) {
        if activeCallID == callID {
            voiceMediaEngine.stop()
            activeCallID = nil
        }
        mediaPipelines.removeValue(forKey: callID)
        if let session = sessions.removeValue(forKey: callID) {
            Task { _ = try? await session.end() }
        }
        incomingCalls.removeValue(forKey: callID)
        statusViewController?.setMediaState("idle")
        statusViewController?.setCallState("idle")
    }

    func callSystemBridgeAudioDidActivate(_ bridge: IOSCallSystemBridge) {
        guard
            let callID = activeCallID,
            let session = sessions[callID],
            let pipeline = mediaPipelines[callID]
        else {
            statusViewController?.setFailure("Call audio activated without an active session")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await self.voiceAudioSession.callKitDidActivate()

            do {
                let snapshot = await session.snapshot()
                if snapshot.state == .idle {
                    _ = try await session.start()
                }
                let readySnapshot = await session.snapshot()
                if readySnapshot.state == .connecting {
                    _ = try await session.connected()
                }

                let format = try self.voiceMediaEngine.start { captured in
                    Task {
                        try? await pipeline.accept(captured)
                    }
                }
                self.statusViewController?.setAudioActive(true)
                self.statusViewController?.setMediaState(
                    "capture/playback \(format.sampleRate)Hz mono PCM16"
                )
                self.statusViewController?.setCallState("active")
                await self.refreshMediaBufferStatus()
            } catch {
                self.voiceMediaEngine.stop()
                self.statusViewController?.setFailure("Call media failed to start")
            }
        }
    }

    func callSystemBridgeAudioDidDeactivate(_ bridge: IOSCallSystemBridge) {
        voiceMediaEngine.stop()
        statusViewController?.setMediaState("idle")
        Task { [weak self] in
            await self?.voiceAudioSession.callKitDidDeactivate()
            self?.statusViewController?.setAudioActive(false)
        }
    }

    func callSystemBridgeDidReset(_ bridge: IOSCallSystemBridge) {
        voiceMediaEngine.stop()
        activeCallID = nil
        sessions.removeAll()
        mediaPipelines.removeAll()
        incomingCalls.removeAll()
        statusViewController?.setCallState("idle")
        statusViewController?.setMediaState("idle")
        Task { [weak self] in
            await self?.voiceAudioSession.callKitDidDeactivate()
            self?.statusViewController?.setAudioActive(false)
        }
    }

    /// Runtime realtime transport can call this boundary when a remote PCM16
    /// frame arrives. The native audio engine owns playback; transport does not.
    func enqueueRemoteVoiceFrame(_ frame: VoiceTransportAudioFrame) {
        do {
            try voiceMediaEngine.enqueuePlayback(frame)
        } catch {
            statusViewController?.setFailure("Remote audio frame rejected")
        }
    }

    private func refreshMediaBufferStatus() async {
        guard let outboundVoiceFrames else { return }
        let snapshot = await outboundVoiceFrames.snapshot()
        statusViewController?.setTransportState(
            "buffered \(snapshot.buffered), dropped \(snapshot.dropped)"
        )
    }
}

@MainActor
final class BodyStatusViewController: UIViewController {
    private let stateLabel = UILabel()
    private let detailLabel = UILabel()
    private var audioConfigured = false
    private var audioActive = false
    private var voipState = "unknown"
    private var callState = "idle"
    private var mediaState = "idle"
    private var transportState = "awaiting realtime transport"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "eCompanion Body"
        view.backgroundColor = .systemBackground

        stateLabel.font = .preferredFont(forTextStyle: .title2)
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [stateLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        render()
    }

    func setAudioConfigured(_ value: Bool) {
        audioConfigured = value
        render()
    }

    func setAudioActive(_ value: Bool) {
        audioActive = value
        render()
    }

    func setVoIPRegistrationState(_ value: String) {
        voipState = value
        render()
    }

    func setCallState(_ value: String) {
        callState = value
        render()
    }

    func setMediaState(_ value: String) {
        mediaState = value
        render()
    }

    func setTransportState(_ value: String) {
        transportState = value
        render()
    }

    func setFailure(_ message: String) {
        stateLabel.text = "Needs attention"
        detailLabel.text = message
    }

    private func render() {
        guard isViewLoaded else { return }
        stateLabel.text = callState == "idle" ? "Ready for Lola" : "Call: \(callState)"
        detailLabel.text = [
            "VoIP: \(voipState)",
            "Audio configured: \(audioConfigured ? "yes" : "no")",
            "Audio active: \(audioActive ? "yes" : "no")",
            "Media: \(mediaState)",
            "Transport: \(transportState)"
        ].joined(separator: "\n")
    }
}
