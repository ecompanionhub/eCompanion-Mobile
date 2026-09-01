import Foundation

public struct RuntimeHTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol RuntimeHTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> RuntimeHTTPResponse
}

public struct URLSessionRuntimeHTTPTransport: RuntimeHTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> RuntimeHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeActionClientError.invalidHTTPResponse
        }
        return RuntimeHTTPResponse(statusCode: http.statusCode, data: data)
    }
}

public struct RuntimeActionClientConfiguration: Sendable, Equatable {
    public let baseURL: URL
    public let deviceCredential: String
    public let deviceLabel: String
    public let platform: String

    public init(
        baseURL: URL,
        deviceCredential: String,
        deviceLabel: String,
        platform: String = "ios-native"
    ) {
        self.baseURL = baseURL
        self.deviceCredential = deviceCredential
        self.deviceLabel = deviceLabel
        self.platform = platform
    }
}

public struct RuntimeQueuedAction: Codable, Sendable, Equatable {
    public let id: UUID
    public let deviceID: String
    public let actorID: String?
    public let capability: String
    public let operation: String
    public let arguments: [String: String]
    public let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceID = "device_id"
        case actorID = "actor_id"
        case capability
        case operation
        case arguments
        case state
    }
}

public struct RuntimeActionCycleResult: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case idle
        case completed
        case failed
    }

    public let outcome: Outcome
    public let actionID: UUID?
    public let capability: String?

    public init(outcome: Outcome, actionID: UUID? = nil, capability: String? = nil) {
        self.outcome = outcome
        self.actionID = actionID
        self.capability = capability
    }
}

public enum RuntimeActionClientError: Error, Sendable, Equatable {
    case invalidBaseURL
    case invalidHTTPResponse
    case runtimeRejected(status: Int, code: String)
    case invalidPayload
}

private struct CapabilityEnvelope: Codable {
    let body_agent: [CapabilityState]
}

private struct DeviceSyncPayload: Codable {
    let label: String
    let platform: String
    let capabilities: CapabilityEnvelope
    let metadata: [String: String]
}

private struct ActionClaimEnvelope: Codable {
    let ok: Bool
    let action: RuntimeQueuedAction?
}

private struct ActionCompletionPayload: Codable {
    let success: Bool
    let result: [String: String]
    let error: String?
}

private struct RuntimeErrorEnvelope: Codable {
    let error: String?
}

public actor RuntimeActionClient {
    private let configuration: RuntimeActionClientConfiguration
    private let transport: any RuntimeHTTPTransport
    private let broker: BodyActionBroker
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        configuration: RuntimeActionClientConfiguration,
        transport: any RuntimeHTTPTransport = URLSessionRuntimeHTTPTransport(),
        broker: BodyActionBroker
    ) {
        self.configuration = configuration
        self.transport = transport
        self.broker = broker
    }

    public func syncCapabilities(metadata: [String: String] = [:]) async throws {
        let snapshot = await broker.snapshot()
        let payload = DeviceSyncPayload(
            label: configuration.deviceLabel,
            platform: configuration.platform,
            capabilities: CapabilityEnvelope(body_agent: snapshot),
            metadata: metadata
        )
        let request = try makeRequest(
            path: "/api/v1/body/device",
            method: "PUT",
            body: encoder.encode(payload)
        )
        _ = try await acceptedResponse(for: request, accepted: 200...299)
    }

    public func claimNextAction() async throws -> RuntimeQueuedAction? {
        let request = try makeRequest(path: "/api/v1/body/actions/claim", method: "POST", body: Data("{}".utf8))
        let response = try await acceptedResponse(for: request, accepted: 200...299)
        guard let envelope = try? decoder.decode(ActionClaimEnvelope.self, from: response.data), envelope.ok else {
            throw RuntimeActionClientError.invalidPayload
        }
        return envelope.action
    }

    public func complete(
        actionID: UUID,
        success: Bool,
        result: [String: String] = [:],
        error: String? = nil
    ) async throws {
        let payload = ActionCompletionPayload(success: success, result: result, error: error)
        let request = try makeRequest(
            path: "/api/v1/body/actions/\(actionID.uuidString.lowercased())/complete",
            method: "POST",
            body: encoder.encode(payload)
        )
        _ = try await acceptedResponse(for: request, accepted: 200...299)
    }

    public func runOneCycle() async throws -> RuntimeActionCycleResult {
        guard let queued = try await claimNextAction() else {
            return RuntimeActionCycleResult(outcome: .idle)
        }

        let request = BodyActionRequest(
            id: queued.id,
            capability: queued.capability,
            operation: queued.operation,
            arguments: queued.arguments
        )

        do {
            let result = try await broker.execute(request)
            try await complete(actionID: queued.id, success: true, result: result.output)
            return RuntimeActionCycleResult(
                outcome: .completed,
                actionID: queued.id,
                capability: queued.capability
            )
        } catch {
            let message = String(describing: error)
            try await complete(actionID: queued.id, success: false, error: message)
            return RuntimeActionCycleResult(
                outcome: .failed,
                actionID: queued.id,
                capability: queued.capability
            )
        }
    }

    private func makeRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        let normalizedBase = configuration.baseURL.absoluteString.hasSuffix("/")
            ? String(configuration.baseURL.absoluteString.dropLast())
            : configuration.baseURL.absoluteString
        guard let url = URL(string: normalizedBase + path) else {
            throw RuntimeActionClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.deviceCredential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        return request
    }

    private func acceptedResponse(
        for request: URLRequest,
        accepted: ClosedRange<Int>
    ) async throws -> RuntimeHTTPResponse {
        let response = try await transport.send(request)
        guard accepted.contains(response.statusCode) else {
            let code = (try? decoder.decode(RuntimeErrorEnvelope.self, from: response.data).error) ?? "HTTP_\(response.statusCode)"
            throw RuntimeActionClientError.runtimeRejected(status: response.statusCode, code: code)
        }
        return response
    }
}
