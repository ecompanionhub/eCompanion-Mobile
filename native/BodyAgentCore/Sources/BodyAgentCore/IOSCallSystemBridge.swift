import Foundation

#if os(iOS)
@preconcurrency import CallKit
@preconcurrency import PushKit

public struct IOSIncomingCallDescriptor: Sendable, Equatable {
    public let callID: UUID
    public let handle: String
    public let displayName: String
    public let conversationID: String
    public let hasVideo: Bool

    public init(
        callID: UUID,
        handle: String,
        displayName: String,
        conversationID: String,
        hasVideo: Bool = false
    ) {
        self.callID = callID
        self.handle = handle
        self.displayName = displayName
        self.conversationID = conversationID
        self.hasVideo = hasVideo
    }
}

public enum IOSCallSystemBridgeError: Error, Sendable, Equatable {
    case invalidVoIPPayload
}

public protocol IOSCallSystemBridgeDelegate: AnyObject {
    func callSystemBridge(_ bridge: IOSCallSystemBridge, didUpdateVoIPToken token: Data)
    func callSystemBridgeDidInvalidateVoIPToken(_ bridge: IOSCallSystemBridge)
    func callSystemBridge(_ bridge: IOSCallSystemBridge, didReceive descriptor: IOSIncomingCallDescriptor)
    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestAnswer callID: UUID)
    func callSystemBridge(_ bridge: IOSCallSystemBridge, didRequestEnd callID: UUID)
    func callSystemBridgeDidReset(_ bridge: IOSCallSystemBridge)
}

public final class IOSCallSystemBridge: NSObject {
    public weak var delegate: IOSCallSystemBridgeDelegate?

    private let provider: CXProvider
    private let callController: CXCallController
    private let pushRegistry: PKPushRegistry

    public init(localizedName: String = "Lola") {
        let configuration = CXProviderConfiguration(localizedName: localizedName)
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = true
        configuration.supportedHandleTypes = [.generic]

        self.provider = CXProvider(configuration: configuration)
        self.callController = CXCallController()
        self.pushRegistry = PKPushRegistry(queue: .main)
        super.init()

        provider.setDelegate(self, queue: .main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
    }

    public func currentVoIPToken() -> Data? {
        pushRegistry.pushToken(for: .voIP)
    }

    public func reportIncomingCall(
        _ descriptor: IOSIncomingCallDescriptor,
        completion: @escaping (Error?) -> Void
    ) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: descriptor.handle)
        update.localizedCallerName = descriptor.displayName
        update.hasVideo = descriptor.hasVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        provider.reportNewIncomingCall(with: descriptor.callID, update: update, completion: completion)
    }

    public func startOutgoingCall(
        callID: UUID,
        handle: String = "Lola",
        hasVideo: Bool = false,
        completion: @escaping (Error?) -> Void
    ) {
        let action = CXStartCallAction(call: callID, handle: CXHandle(type: .generic, value: handle))
        action.isVideo = hasVideo
        callController.request(CXTransaction(action: action), completion: completion)
    }

    public func reportOutgoingConnecting(callID: UUID, at date: Date = Date()) {
        provider.reportOutgoingCall(with: callID, startedConnectingAt: date)
    }

    public func reportOutgoingConnected(callID: UUID, at date: Date = Date()) {
        provider.reportOutgoingCall(with: callID, connectedAt: date)
    }

    public func reportCallEnded(callID: UUID, reason: CXCallEndedReason = .remoteEnded, at date: Date = Date()) {
        provider.reportCall(with: callID, endedAt: date, reason: reason)
    }

    public static func descriptor(from payload: [AnyHashable: Any]) throws -> IOSIncomingCallDescriptor {
        guard
            let callIDText = payload["call_uuid"] as? String,
            let callID = UUID(uuidString: callIDText),
            let conversationID = payload["conversation_id"] as? String,
            !conversationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw IOSCallSystemBridgeError.invalidVoIPPayload
        }

        let handle = (payload["handle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (payload["display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return IOSIncomingCallDescriptor(
            callID: callID,
            handle: handle?.isEmpty == false ? handle! : "Lola",
            displayName: displayName?.isEmpty == false ? displayName! : "Lola",
            conversationID: conversationID,
            hasVideo: payload["has_video"] as? Bool ?? false
        )
    }

    private func handleIncomingVoIPPayload(
        _ payload: PKPushPayload,
        completion: @escaping () -> Void
    ) {
        do {
            let descriptor = try Self.descriptor(from: payload.dictionaryPayload)
            reportIncomingCall(descriptor) { [weak self] error in
                defer { completion() }
                guard error == nil, let self else { return }
                self.delegate?.callSystemBridge(self, didReceive: descriptor)
            }
        } catch {
            completion()
        }
    }
}

extension IOSCallSystemBridge: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        delegate?.callSystemBridgeDidReset(self)
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        delegate?.callSystemBridge(self, didRequestAnswer: action.callUUID)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        delegate?.callSystemBridge(self, didRequestEnd: action.callUUID)
        action.fulfill()
    }
}

extension IOSCallSystemBridge: PKPushRegistryDelegate {
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        delegate?.callSystemBridge(self, didUpdateVoIPToken: pushCredentials.token)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        delegate?.callSystemBridgeDidInvalidateVoIPToken(self)
    }

    public func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        handleIncomingVoIPPayload(payload, completion: completion)
    }
}
#endif
