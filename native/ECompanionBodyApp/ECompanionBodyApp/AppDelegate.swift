import UIKit
import BodyAgentCore

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, IOSCallSystemBridgeDelegate {
    var window: UIWindow?

    private let voiceAudioSession = IOSVoiceAudioSession()
    private var callSystemBridge: IOSCallSystemBridge?
    private var incomingCalls: [UUID: IOSIncomingCallDescriptor] = [:]
    private var sessions: [UUID: VoiceCallSession] = [:]
    private weak var statusViewController: BodyStatusViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let bridge = IOSCallSystemBridge(localizedName: "eCompanion")
        bridge.delegate = self
        callSystemBridge = bridge

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
                await MainActor.run { self?.statusViewController?.setAudioConfigured(true) }
            } catch {
                await MainActor.run { self?.statusViewController?.setFailure("Audio configuration failed") }
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
        }
        statusViewController?.setCallState("incoming")
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestAnswer callID: UUID) {
        statusViewController?.setCallState("connecting")
        guard let session = sessions[callID] else { return }
        Task {
            _ = try? await session.start()
        }
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestEnd callID: UUID) {
        if let session = sessions.removeValue(forKey: callID) {
            Task { _ = try? await session.end() }
        }
        incomingCalls.removeValue(forKey: callID)
        statusViewController?.setCallState("idle")
    }

    func callSystemBridgeAudioDidActivate(_ bridge: IOSCallSystemBridge) {
        Task { [weak self] in
            await self?.voiceAudioSession.callKitDidActivate()
            await MainActor.run {
                self?.statusViewController?.setAudioActive(true)
                self?.statusViewController?.setCallState("active")
            }
        }
    }

    func callSystemBridgeAudioDidDeactivate(_ bridge: IOSCallSystemBridge) {
        Task { [weak self] in
            await self?.voiceAudioSession.callKitDidDeactivate()
            await MainActor.run { self?.statusViewController?.setAudioActive(false) }
        }
    }

    func callSystemBridgeDidReset(_ bridge: IOSCallSystemBridge) {
        sessions.removeAll()
        incomingCalls.removeAll()
        statusViewController?.setCallState("idle")
        Task { [weak self] in
            await self?.voiceAudioSession.callKitDidDeactivate()
            await MainActor.run { self?.statusViewController?.setAudioActive(false) }
        }
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
            "Audio active: \(audioActive ? "yes" : "no")"
        ].joined(separator: "\n")
    }
}
