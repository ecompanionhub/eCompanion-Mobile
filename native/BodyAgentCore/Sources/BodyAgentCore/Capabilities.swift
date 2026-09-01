import Foundation

public enum CapabilityTier: String, Codable, Sendable, CaseIterable {
    case stock
    case integration
    case elevated
}

public enum CapabilityAvailability: String, Codable, Sendable {
    case unavailable
    case available
    case degraded
}

public struct CapabilityState: Codable, Sendable, Equatable {
    public let id: String
    public let tier: CapabilityTier
    public var availability: CapabilityAvailability
    public var reason: String?

    public init(
        id: String,
        tier: CapabilityTier,
        availability: CapabilityAvailability = .unavailable,
        reason: String? = nil
    ) {
        self.id = id
        self.tier = tier
        self.availability = availability
        self.reason = reason
    }
}

public enum BodyCapabilities {
    public static let catalog: [CapabilityState] = [
        .init(id: "presence.publish", tier: .stock),
        .init(id: "presence.observe_local", tier: .stock),
        .init(id: "audio.capture", tier: .stock),
        .init(id: "audio.playback", tier: .stock),
        .init(id: "audio.wake_word", tier: .stock),
        .init(id: "audio.stt", tier: .stock),
        .init(id: "audio.tts", tier: .stock),
        .init(id: "camera.capture", tier: .stock),
        .init(id: "camera.stream", tier: .stock),
        .init(id: "call.audio", tier: .stock),
        .init(id: "call.video", tier: .stock),
        .init(id: "call.webrtc", tier: .stock),
        .init(id: "call.signal", tier: .integration),
        .init(id: "message.send", tier: .integration),
        .init(id: "message.receive", tier: .integration),
        .init(id: "message.media.send", tier: .integration),
        .init(id: "message.media.receive", tier: .integration),
        .init(id: "transport.telegram", tier: .integration),
        .init(id: "transport.discord", tier: .integration),
        .init(id: "transport.runtime", tier: .integration),
        .init(id: "transport.local_grid", tier: .integration),
        .init(id: "device.display.present", tier: .stock),
        .init(id: "device.screen.attention", tier: .stock),
        .init(id: "device.open_url", tier: .stock),
        .init(id: "device.shortcut.invoke", tier: .stock),
        .init(id: "device.location", tier: .stock),
        .init(id: "device.motion", tier: .stock),
        .init(id: "device.clipboard", tier: .stock),
        .init(id: "device.files.app_owned", tier: .stock),
        .init(id: "elevated.background_daemon", tier: .elevated),
        .init(id: "elevated.springboard", tier: .elevated),
        .init(id: "elevated.screen.wake", tier: .elevated),
        .init(id: "elevated.app.launch", tier: .elevated),
        .init(id: "elevated.app.control", tier: .elevated),
        .init(id: "elevated.notification.observe", tier: .elevated),
        .init(id: "elevated.system.event.observe", tier: .elevated)
    ]

    public static func tier(for capability: String) -> CapabilityTier? {
        catalog.first(where: { $0.id == capability })?.tier
    }
}
