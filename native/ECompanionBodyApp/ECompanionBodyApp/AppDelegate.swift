import UIKit
import BodyAgentCore

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate, IOSCallSystemBridgeDelegate {
    var window: UIWindow?

    private static let runtimeBaseURL = URL(string: "https://ecompanion-ene7.onrender.com")!
    private static let nativeDeviceIDKey = "ecompanion.native.device_id"
    private static let maxActionsPerActivation = 8

    private let voiceAudioSession = IOSVoiceAudioSession()
    private let voiceMediaEngine = IOSVoiceMediaEngine()
    private let credentialStore = IOSRuntimeCredentialStore()
    private let enrollmentStore = UserDefaultsRuntimeEnrollmentProfileStore()
    private let runtimeBroker = BodyActionBroker()

    private var callSystemBridge: IOSCallSystemBridge?
    private var runtimeClient: RuntimeActionClient?
    private var enrollmentProfile: RuntimeEnrollmentProfile?
    private var actionCycleInFlight = false

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
        status.onPairRequested = { [weak self] code in
            self?.pairNativeBody(code: code)
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

        status.setVoIPRegistrationState(
            bridge.currentVoIPToken() == nil
                ? "PushKit registering"
                : "PushKit ready · Runtime registration unavailable"
        )
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        runRuntimeCycle()
    }

    func callSystemBridge(_ bridge: IOSCallSystemBridge, didUpdateVoIPToken token: Data) {
        // Runtime main currently exposes no device-scoped VoIP registration endpoint.
        // Keep the PushKit token inside the OS/native process only; never persist it as
        // a substitute registration authority.
        statusViewController?.setVoIPRegistrationState(
            token.isEmpty
                ? "PushKit token invalid"
                : "PushKit ready · Runtime registration unavailable"
        )
    }

    func callSystemBridgeDidInvalidateVoIPToken(_ bridge: IOSCallSystemBridge) {
        statusViewController?.setVoIPRegistrationState("PushKit token invalidated")
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
            let profile = try enrollmentStore.loadProfile()
            let credential = try credentialStore.loadCredential()

            guard let profile, let credential, !credential.isEmpty else {
                if profile != nil {
                    try? enrollmentStore.clearProfile()
                }
                statusViewController?.setEnrollmentState("Not connected", paired: false)
                return
            }

            guard canonicalRuntime(profile.runtimeBaseURL) else {
                try? enrollmentStore.clearProfile()
                try? credentialStore.clearCredential()
                statusViewController?.setEnrollmentState("Reconnect required", paired: false)
                return
            }

            configureRuntime(profile: profile, credential: credential)
            statusViewController?.setEnrollmentState(
                profile.assignedActorID == nil
                    ? "Connected · companion assignment needed"
                    : "Connected",
                paired: true
            )
            runRuntimeCycle()
        } catch {
            runtimeClient = nil
            enrollmentProfile = nil
            statusViewController?.setEnrollmentState("Reconnect required", paired: false)
        }
    }

    private func pairNativeBody(code: String) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            statusViewController?.setEnrollmentState("Pairing code required", paired: false)
            return
        }

        statusViewController?.setPairingBusy(true)
        statusViewController?.setEnrollmentState("Connecting…", paired: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                let pairing = try RuntimePairingClient(baseURL: Self.runtimeBaseURL)
                let result = try await pairing.claim(
                    code: normalizedCode,
                    device: .nativeBody(
                        id: self.stableNativeDeviceID(),
                        label: "eCompanion iPhone"
                    )
                )
                let profile = await pairing.enrollmentProfile(from: result)

                // The bearer credential has exactly one persistence authority: Keychain.
                // UserDefaults receives only the non-secret enrollment profile.
                do {
                    try self.enrollmentStore.saveProfile(profile)
                    try self.credentialStore.saveCredential(result.credential.token)
                } catch {
                    try? self.enrollmentStore.clearProfile()
                    try? self.credentialStore.clearCredential()
                    throw error
                }

                self.configureRuntime(
                    profile: profile,
                    credential: result.credential.token
                )
                self.statusViewController?.clearPairingCode()
                self.statusViewController?.setEnrollmentState(
                    result.device.assignedActorID == nil
                        ? "Connected · companion assignment needed"
                        : "Connected",
                    paired: true
                )
                self.runRuntimeCycle()
            } catch let error as RuntimePairingClientError {
                self.statusViewController?.setEnrollmentState(
                    self.pairingMessage(for: error),
                    paired: false
                )
            } catch {
                self.statusViewController?.setEnrollmentState(
                    "Could not connect this iPhone",
                    paired: false
                )
            }
            self.statusViewController?.setPairingBusy(false)
        }
    }

    private func configureRuntime(
        profile: RuntimeEnrollmentProfile,
        credential: String
    ) {
        enrollmentProfile = profile
        runtimeClient = RuntimeActionClient(
            configuration: RuntimeActionClientConfiguration(
                baseURL: Self.runtimeBaseURL,
                deviceCredential: credential,
                deviceLabel: profile.deviceLabel,
                platform: "ios-native"
            ),
            broker: runtimeBroker
        )
    }

    private func runRuntimeCycle() {
        guard !actionCycleInFlight, let client = runtimeClient else { return }
        actionCycleInFlight = true
        statusViewController?.setRuntimeState("Syncing")

        Task { [weak self] in
            guard let self else { return }
            defer { self.actionCycleInFlight = false }

            do {
                try await client.syncCapabilities(metadata: [
                    "body_protocol": "ecompanion-body-ios-v1",
                    "install_mode": "native"
                ])

                var handled = 0
                for _ in 0..<Self.maxActionsPerActivation {
                    let cycle = try await client.runOneCycle()
                    if cycle.outcome == .idle { break }
                    handled += 1
                }

                self.statusViewController?.setRuntimeState(
                    handled == 0
                        ? "Connected"
                        : "Completed \(handled) authorized action\(handled == 1 ? "" : "s")"
                )
            } catch let error as RuntimeActionClientError {
                self.statusViewController?.setRuntimeState(
                    self.runtimeActionMessage(for: error)
                )
            } catch {
                self.statusViewController?.setRuntimeState("Runtime action unavailable")
            }
        }
    }

    private func canonicalRuntime(_ url: URL) -> Bool {
        var expected = Self.runtimeBaseURL.absoluteString
        var actual = url.absoluteString
        if expected.hasSuffix("/") { expected.removeLast() }
        if actual.hasSuffix("/") { actual.removeLast() }
        return actual == expected
    }

    private func stableNativeDeviceID() -> String {
        if let stored = UserDefaults.standard.string(
            forKey: Self.nativeDeviceIDKey
        ), !stored.isEmpty {
            return stored
        }
        let created = "ebody:\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(created, forKey: Self.nativeDeviceIDKey)
        return created
    }

    private func pairingMessage(for error: RuntimePairingClientError) -> String {
        switch error {
        case .runtimeRejected(_, let code):
            return code == "PAIRING_GRANT_INVALID"
                ? "Pairing code expired or already used"
                : "Pairing was rejected"
        case .invalidPairingCode:
            return "Invalid pairing code"
        case .missingCredentialToken, .invalidPayload:
            return "Invalid Runtime pairing response"
        case .invalidBaseURL:
            return "Runtime connection is invalid"
        default:
            return "Pairing failed"
        }
    }

    private func runtimeActionMessage(for error: RuntimeActionClientError) -> String {
        switch error {
        case .runtimeRejected(let status, _):
            if status == 401 || status == 403 {
                return "Reconnect required"
            }
            return "Runtime action unavailable"
        case .invalidBaseURL, .invalidHTTPResponse, .invalidPayload:
            return "Runtime action unavailable"
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
    var onPairRequested: ((String) -> Void)?

    private let stateLabel = UILabel()
    private let detailLabel = UILabel()
    private let pairingCodeField = UITextField()
    private let pairButton = UIButton(type: .system)
    private let pairingStack = UIStackView()

    private var audioConfigured = false
    private var audioActive = false
    private var voipState = "unknown"
    private var callState = "idle"
    private var mediaState = "idle"
    private var transportState = "awaiting realtime transport"
    private var enrollmentState = "Not connected"
    private var runtimeState = "Not connected"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "eCompanion"
        view.backgroundColor = .systemBackground

        stateLabel.font = .preferredFont(forTextStyle: .title2)
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        pairingCodeField.borderStyle = .roundedRect
        pairingCodeField.placeholder = "One-time pairing code"
        pairingCodeField.autocapitalizationType = .none
        pairingCodeField.autocorrectionType = .no
        pairingCodeField.textContentType = .oneTimeCode
        pairingCodeField.delegate = self
        pairingCodeField.accessibilityIdentifier = "pairingCode"

        pairButton.setTitle("Connect this iPhone", for: .normal)
        pairButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        pairButton.addTarget(self, action: #selector(pairTapped), for: .touchUpInside)
        pairButton.accessibilityIdentifier = "pairNativeBody"

        pairingStack.axis = .vertical
        pairingStack.spacing = 10
        pairingStack.addArrangedSubview(pairingCodeField)
        pairingStack.addArrangedSubview(pairButton)

        let stack = UIStackView(
            arrangedSubviews: [stateLabel, detailLabel, pairingStack]
        )
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            stack.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        render()
    }

    @objc private func pairTapped() {
        view.endEditing(true)
        onPairRequested?(pairingCodeField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        pairTapped()
        return true
    }

    func setPairingBusy(_ value: Bool) {
        pairButton.isEnabled = !value
        pairingCodeField.isEnabled = !value
        pairButton.setTitle(
            value ? "Connecting…" : "Connect this iPhone",
            for: .normal
        )
    }

    func clearPairingCode() {
        pairingCodeField.text = ""
    }

    func setEnrollmentState(_ value: String, paired: Bool) {
        enrollmentState = value
        pairingStack.isHidden = paired
        render()
    }

    func setRuntimeState(_ value: String) {
        runtimeState = value
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
        stateLabel.text = callState == "idle"
            ? (enrollmentState == "Connected" ? "Ready for Lola" : enrollmentState)
            : "Call: \(callState)"

        detailLabel.text = [
            "Runtime: \(runtimeState)",
            "PushKit: \(voipState)",
            "Audio: \(audioConfigured ? "ready" : "preparing")\(audioActive ? " · active" : "")",
            "Media: \(mediaState)",
            "Transport: \(transportState)"
        ].joined(separator: "\n")
    }
}
