import Foundation

public struct BodyActionRequest: Sendable, Equatable {
    public let id: UUID
    public let capability: String
    public let operation: String
    public let arguments: [String: String]

    public init(
        id: UUID = UUID(),
        capability: String,
        operation: String,
        arguments: [String: String] = [:]
    ) {
        self.id = id
        self.capability = capability
        self.operation = operation
        self.arguments = arguments
    }
}

public struct BodyActionResult: Sendable, Equatable {
    public let requestID: UUID
    public let capability: String
    public let output: [String: String]

    public init(requestID: UUID, capability: String, output: [String: String] = [:]) {
        self.requestID = requestID
        self.capability = capability
        self.output = output
    }
}

public enum BodyActionError: Error, Sendable, Equatable {
    case unknownCapability(String)
    case capabilityUnavailable(String)
    case executorMissing(String)
    case operationDenied(String)
}

public protocol BodyActionExecutor: Sendable {
    var capabilities: Set<String> { get }
    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult
}

public actor BodyActionBroker {
    private var states: [String: CapabilityState]
    private var executors: [String: any BodyActionExecutor] = [:]

    public init(catalog: [CapabilityState] = BodyCapabilities.catalog) {
        self.states = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    public func snapshot() -> [CapabilityState] {
        states.values.sorted { $0.id < $1.id }
    }

    public func setAvailability(
        _ availability: CapabilityAvailability,
        for capability: String,
        reason: String? = nil
    ) throws {
        guard var state = states[capability] else {
            throw BodyActionError.unknownCapability(capability)
        }
        state.availability = availability
        state.reason = reason
        states[capability] = state
    }

    public func register(_ executor: any BodyActionExecutor) throws {
        for capability in executor.capabilities {
            guard states[capability] != nil else {
                throw BodyActionError.unknownCapability(capability)
            }
            executors[capability] = executor
        }
    }

    public func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        guard let state = states[request.capability] else {
            throw BodyActionError.unknownCapability(request.capability)
        }
        guard state.availability == .available || state.availability == .degraded else {
            throw BodyActionError.capabilityUnavailable(request.capability)
        }
        guard let executor = executors[request.capability] else {
            throw BodyActionError.executorMissing(request.capability)
        }
        return try await executor.execute(request)
    }
}
