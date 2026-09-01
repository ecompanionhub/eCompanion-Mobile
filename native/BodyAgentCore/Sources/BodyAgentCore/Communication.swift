import Foundation

public enum CommunicationKind: String, Codable, Sendable {
    case message
    case media
    case audioCall
    case videoCall
}

public struct CommunicationTarget: Codable, Sendable, Equatable {
    public let transport: String
    public let address: String

    public init(transport: String, address: String) {
        self.transport = transport
        self.address = address
    }
}

public struct CommunicationIntent: Codable, Sendable, Equatable {
    public let id: UUID
    public let kind: CommunicationKind
    public let target: CommunicationTarget
    public let text: String?
    public let mediaReference: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        kind: CommunicationKind,
        target: CommunicationTarget,
        text: String? = nil,
        mediaReference: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.target = target
        self.text = text
        self.mediaReference = mediaReference
        self.metadata = metadata
    }

    public var requiredCapability: String {
        switch kind {
        case .message:
            return "message.send"
        case .media:
            return "message.media.send"
        case .audioCall:
            return "call.audio"
        case .videoCall:
            return "call.video"
        }
    }
}
