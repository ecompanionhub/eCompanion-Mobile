import Foundation

public struct RuntimePairingDeviceDescriptor: Codable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let platform: String
    public let capabilities: [String: JSONValue]
    public let metadata: [String: JSONValue]

    public init(
        id: String,
        label: String,
        platform: String = "ios-native",
        capabilities: [String: JSONValue],
        metadata: [String: JSONValue]
    ) {
        self.id = id
        self.label = label
        self.platform = platform
        self.capabilities = capabilities
        self.metadata = metadata
    }

    public static func nativeBody(id: String, label: String = "eCompanion Body") -> RuntimePairingDeviceDescriptor {
        RuntimePairingDeviceDescriptor(
            id: id,
            label: label,
            capabilities: [
                "display": true,
                "audio_output": true,
                "microphone": true,
                "camera": true,
                "notifications": true,
                "native_callkit": true,
                "native_pushkit": true,
                "background_call_audio": true
            ],
            metadata: [
                "body_protocol": "ecompanion-body-ios-v1",
                "install_mode": "native"
            ]
        )
    }
}

public struct RuntimePairingDevice: Codable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let platform: String?
    public let assignedActorID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case platform
        case assignedActorID = "assigned_actor_id"
    }
}

public struct RuntimePairingCredential: Codable, Sendable, Equatable {
    public let id: String
    public let token: String
    public let scopes: [String]
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case token
        case scopes
        case createdAt = "created_at"
    }
}

public struct RuntimePairingResult: Codable, Sendable, Equatable {
    public let relinked: Bool
    public let device: RuntimePairingDevice
    public let credential: RuntimePairingCredential
}

public struct RuntimeEnrollmentProfile: Codable, Sendable, Equatable {
    public let runtimeBaseURL: URL
    public let deviceID: String
    public let deviceLabel: String
    public let credentialID: String
    public let assignedActorID: String?

    public init(
        runtimeBaseURL: URL,
        deviceID: String,
        deviceLabel: String,
        credentialID: String,
        assignedActorID: String?
    ) {
        self.runtimeBaseURL = runtimeBaseURL
        self.deviceID = deviceID
        self.deviceLabel = deviceLabel
        self.credentialID = credentialID
        self.assignedActorID = assignedActorID
    }
}

public enum RuntimePairingClientError: Error, Sendable, Equatable {
    case invalidBaseURL
    case invalidPairingCode
    case invalidDeviceID
    case invalidDeviceLabel
    case invalidHTTPResponse
    case runtimeRejected(status: Int, code: String)
    case invalidPayload
    case missingCredentialToken
}

private struct RuntimePairingRequest: Codable {
    let code: String
    let device: RuntimePairingDeviceDescriptor
}

private struct RuntimePairingEnvelope: Codable {
    let ok: Bool
    let relinked: Bool
    let device: RuntimePairingDevice
    let credential: RuntimePairingCredential
}

private struct RuntimePairingErrorEnvelope: Codable {
    let error: String?
}

public actor RuntimePairingClient {
    private let baseURL: URL
    private let transport: any RuntimeHTTPTransport
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL, transport: any RuntimeHTTPTransport = URLSessionRuntimeHTTPTransport()) throws {
        guard let scheme = baseURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw RuntimePairingClientError.invalidBaseURL
        }
        guard baseURL.host != nil else { throw RuntimePairingClientError.invalidBaseURL }
        self.baseURL = baseURL
        self.transport = transport
    }

    public func claim(code: String, device: RuntimePairingDeviceDescriptor) async throws -> RuntimePairingResult {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedID = device.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = device.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty, normalizedCode.count <= 128 else {
            throw RuntimePairingClientError.invalidPairingCode
        }
        guard !normalizedID.isEmpty, normalizedID.count <= 128 else {
            throw RuntimePairingClientError.invalidDeviceID
        }
        guard !normalizedLabel.isEmpty, normalizedLabel.count <= 120 else {
            throw RuntimePairingClientError.invalidDeviceLabel
        }

        let descriptor = RuntimePairingDeviceDescriptor(
            id: normalizedID,
            label: normalizedLabel,
            platform: device.platform,
            capabilities: device.capabilities,
            metadata: device.metadata
        )
        let body = try encoder.encode(RuntimePairingRequest(code: normalizedCode, device: descriptor))
        var request = URLRequest(url: endpoint("/api/v1/device-pairing/claim"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        let response = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            let code = (try? decoder.decode(RuntimePairingErrorEnvelope.self, from: response.data).error)
                ?? "HTTP_\(response.statusCode)"
            throw RuntimePairingClientError.runtimeRejected(status: response.statusCode, code: code)
        }
        guard let envelope = try? decoder.decode(RuntimePairingEnvelope.self, from: response.data), envelope.ok else {
            throw RuntimePairingClientError.invalidPayload
        }
        guard !envelope.credential.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuntimePairingClientError.missingCredentialToken
        }
        return RuntimePairingResult(
            relinked: envelope.relinked,
            device: envelope.device,
            credential: envelope.credential
        )
    }

    public func enrollmentProfile(from result: RuntimePairingResult) -> RuntimeEnrollmentProfile {
        RuntimeEnrollmentProfile(
            runtimeBaseURL: baseURL,
            deviceID: result.device.id,
            deviceLabel: result.device.label,
            credentialID: result.credential.id,
            assignedActorID: result.device.assignedActorID
        )
    }

    private func endpoint(_ path: String) -> URL {
        let normalized = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return URL(string: normalized + path)!
    }
}
