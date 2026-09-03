import UIKit
import BodyAgentCore

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate, IOSCallSystemBridgeDelegate {
    var window: UIWindow?

    private static let pendingVoipTokenKey = "ecompanion.pending_voip_token"
    private static let nativeDeviceIDKey = "ecompanion.native.device_id"

    private let voiceAudioSession = IOSVoiceAudioSession()
    private let voiceMediaEngine = IOSVoiceMediaEngine()
    private let credentialStore = IOSRuntimeCredentialStore()
    private let enrollmentStore = UserDefaultsRuntimeEnrollmentProfileStore()
    private let runtimeBroker = BodyActionBroker()

    private var callSystemBridge: IOSCallSystemBridge?
    private var runtimeClient: RuntimeActionClient?
    private var enrollmentProfile: RuntimeEnrollmentProfile?
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
        status.onPairRequested = { [weak self] runtimeText, code in
            self?.pairNativeBody(runtimeText: runtimeText, code: code)
        }
        statusViewController = status
        let navigation = UINavigationController(rootViewController: status)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window

        restoreEnrollment()

        Task { [weak self] in
            do {
                try await self?.voiceAudioSession.configureForCallKit()
                self?.statusViewController?.setAudioConfigured(true)
            } catch {
                self?.statusViewController?.setFailure("Audio configuration failed")
            }
        }

        if bridge.currentVoIPToken() == nil {
            status.setVoIPRegistrationState("requesting PushKit token")
        } else {
            status.setVoIPRegistrationState("PushKit token available")
            attemptVoipRegistration()
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        attemptVoipRegistration()
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didUpdateVoIPToken token: Data) {
        let tokenHex = token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenHex, forKey: Self.pendingVoipTokenKey)
        statusViewController?.setVoIPRegistrationState("PushKit token received")
        attemptVoipRegistration()
    }

    func callSystemBridgeDidInvalidateVoIPToken(_ bridge: IOSCallSystemBridge) {
        UserDefaults.standard.removeObject(forKey: Self.pendingVoipTokenKey)
        let client = runtimeClient
        statusViewController?.setVoIPRegistrationState("PushKit token invalidated")
        guard let client else { return }
        Task { [weak self] in
            do {
                try await client.clearVoip()
                self?.statusViewController?.setVoIPRegistrationState("Runtime registration cleared")
            } catch {
                self?.statusViewController?.setVoIPRegistrationState("Runtime clear pending")
            }
        }
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

    private func restoreEnrollment() {
        do {
            guard
                let profile = try enrollmentStore.loadProfile(),
                let credential = try credentialStore.loadCredential(),
                !credential.isEmpty
            else {
                statusViewController?.setEnrollmentState("not paired")
                return
            }
            configureRuntime(profile: profile, credential: credential)
            statusViewController?.setEnrollmentRuntime(profile.runtimeBaseURL.absoluteString)
            statusViewController?.setEnrollmentState(
                profile.assignedActorID == nil ? "paired · no actor assigned" : "paired · actor assigned"
            )
        } catch {
            runtimeClient = nil
            enrollmentProfile = nil
            statusViewController?.setEnrollmentState("stored enrollment unavailable")
        }
    }

    private func pairNativeBody(runtimeText: String, code: String) {
        let normalizedRuntime = runtimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let runtimeURL = URL(string: normalizedRuntime),
            let scheme = runtimeURL.scheme?.lowercased(),
            (scheme == "https" || scheme == "http"),
            runtimeURL.host != nil
        else {
            statusViewController?.setEnrollmentState("invalid Runtime URL")
            return
        }

        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            statusViewController?.setEnrollmentState("pairing code required")
            return
        }

        statusViewController?.setPairingBusy(true)
        statusViewController?.setEnrollmentState("pairing…")
        let deviceID = stableNativeDeviceID()

        Task { [weak self] in
            guard let self else { return }
            do {
                let pairing = try RuntimePairingClient(baseURL: runtimeURL)
                let result = try await pairing.claim(
                    code: normalizedCode,
                    device: .nativeBody(id: deviceID, label: "eCompanion Body")
                )
                let profile = await pairing.enrollmentProfile(from: result)

                do {
                    try self.enrollmentStore.saveProfile(profile)
                    try self.credentialStore.saveCredential(result.credential.token)
                } catch {
                    try? self.enrollmentStore.clearProfile()
                    try? self.credentialStore.clearCredential()
                    throw error
                }

                self.configureRuntime(profile: profile, credential: result.credential.token)
                self.statusViewController?.setEnrollmentRuntime(profile.runtimeBaseURL.absoluteString)
                self.statusViewController?.clearPairingCode()
                self.statusViewController?.setEnrollmentState(
                    result.device.assignedActorID == nil
                        ? "paired · no actor assigned"
                        : (result.relinked ? "reconnected · actor assigned" : "paired · actor assigned")
                )
                self.attemptVoipRegistration()
            } catch let error as RuntimePairingClientError {
                self.statusViewController?.setEnrollmentState(self.pairingMessage(for: error))
            } catch {
                self.statusViewController?.setEnrollmentState("pairing failed")
            }
            self.statusViewController?.setPairingBusy(false)
        }
    }

    private func configureRuntime(profile: RuntimeEnrollmentProfile, credential: String) {
        enrollmentProfile = profile
        runtimeClient = RuntimeActionClient(
            configuration: RuntimeActionClientConfiguration(
                baseURL: profile.runtimeBaseURL,
                deviceCredential: credential,
                deviceLabel: profile.deviceLabel,
                platform: "ios-native"
            ),
            broker: runtimeBroker
        )
    }

    private func attemptVoipRegistration() {
        guard
            let client = runtimeClient,
            let token = UserDefaults.standard.string(forKey: Self.pendingVoipTokenKey),
            !token.isEmpty,
            let bundleID = Bundle.main.bundleIdentifier,
            !bundleID.isEmpty
        else { return }

        #if DEBUG
        let environment: RuntimeVoipEnvironment = .sandbox
        #else
        let environment: RuntimeVoipEnvironment = .production
        #endif

        statusViewController?.setVoIPRegistrationState("registering with Runtime…")
        Task { [weak self] in
            do {
                try await client.registerVoip(
                    RuntimeVoipRegistration(
                        tokenHex: token,
                        bundleID: bundleID,
                        environment: environment
                    )
                )
                self?.statusViewController?.setVoIPRegistrationState("Runtime registered")
            } catch {
                self?.statusViewController?.setVoIPRegistrationState("Runtime registration pending")
            }
        }
    }

    private func stableNativeDeviceID() -> String {
        if let stored = UserDefaults.standard.string(forKey: Self.nativeDeviceIDKey), !stored.isEmpty {
            return stored
        }
        let created = "ebody:\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(created, forKey: Self.nativeDeviceIDKey)
        return created
    }

    private func pairingMessage(for error: RuntimePairingClientError) -> String {
        switch error {
        case .runtimeRejected(_, let code): return "pairing rejected · \(code)"
        case .invalidPairingCode: return "invalid pairing code"
        case .invalidBaseURL: return "invalid Runtime URL"
        case .missingCredentialToken, .invalidPayload: return "invalid Runtime pairing response"
        default: return "pairing failed"
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
final class BodyStatusViewController: UIViewController, UITextFieldDelegate {
    var onPairRequested: ((String, String) -> Void)?

    private let stateLabel = UILabel()
    private let detailLabel = UILabel()
    private let runtimeField = UITextField()
    private let pairingCodeField = UITextField()
    private let pairButton = UIButton(type: .system)

    private var audioConfigured = false
    private var audioActive = false
    private var voipState = "unknown"
    private var callState = "idle"
    private var mediaState = "idle"
    private var transportState = "awaiting realtime transport"
    private var enrollmentState = "not paired"

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

        runtimeField.borderStyle = .roundedRect
        runtimeField.placeholder = "Runtime URL"
        runtimeField.keyboardType = .URL
        runtimeField.textContentType = .URL
        runtimeField.autocapitalizationType = .none
        runtimeField.autocorrectionType = .no
        runtimeField.delegate = self
        runtimeField.accessibilityIdentifier = "runtimeBaseURL"

        pairingCodeField.borderStyle = .roundedRect
        pairingCodeField.placeholder = "Pairing code"
        pairingCodeField.autocapitalizationType = .none
        pairingCodeField.autocorrectionType = .no
        pairingCodeField.delegate = self
        pairingCodeField.accessibilityIdentifier = "pairingCode"

        pairButton.setTitle("Pair iPhone", for: .normal)
        pairButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        pairButton.addTarget(self, action: #selector(pairTapped), for: .touchUpInside)
        pairButton.accessibilityIdentifier = "pairNativeBody"

        let enrollmentStack = UIStackView(arrangedSubviews: [runtimeField, pairingCodeField, pairButton])
        enrollmentStack.axis = .vertical
        enrollmentStack.spacing = 10

        let stack = UIStackView(arrangedSubviews: [stateLabel, detailLabel, enrollmentStack])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        render()
    }

    @objc private func pairTapped() {
        view.endEditing(true)
        onPairRequested?(runtimeField.text ?? "", pairingCodeField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === runtimeField {
            pairingCodeField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            pairTapped()
        }
        return true
    }

    func setPairingBusy(_ value: Bool) {
        pairButton.isEnabled = !value
        runtimeField.isEnabled = !value
        pairingCodeField.isEnabled = !value
        pairButton.setTitle(value ? "Pairing…" : "Pair iPhone", for: .normal)
    }

    func setEnrollmentRuntime(_ value: String) {
        runtimeField.text = value
    }

    func clearPairingCode() {
        pairingCodeField.text = ""
    }

    func setEnrollmentState(_ value: String) {
        enrollmentState = value
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
        if callState != "idle" {
            stateLabel.text = "Call: \(callState)"
        } else if enrollmentState.hasPrefix("paired") || enrollmentState.hasPrefix("reconnected") {
            stateLabel.text = "Ready for Lola"
        } else {
            stateLabel.text = "Pair this iPhone"
        }
        detailLabel.text = [
            "Enrollment: \(enrollmentState)",
            "VoIP: \(voipState)",
            "Audio configured: \(audioConfigured ? "yes" : "no")",
            "Audio active: \(audioActive ? "yes" : "no")",
            "Media: \(mediaState)",
            "Transport: \(transportState)"
        ].joined(separator: "\n")
    }
}
