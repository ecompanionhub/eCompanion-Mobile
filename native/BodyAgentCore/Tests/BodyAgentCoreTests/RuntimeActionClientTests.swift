import Foundation
import XCTest
@testable import BodyAgentCore

private actor RecordingRuntimeTransport: RuntimeHTTPTransport {
    private var responses: [RuntimeHTTPResponse]
    private var recorded: [URLRequest] = []

    init(responses: [RuntimeHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> RuntimeHTTPResponse {
        recorded.append(request)
        guard !responses.isEmpty else {
            return RuntimeHTTPResponse(statusCode: 500, data: Data("{\"error\":\"NO_MOCK_RESPONSE\"}".utf8))
        }
        return responses.removeFirst()
    }

    func requests() -> [URLRequest] { recorded }
}

private struct StructuredCameraExecutor: BodyActionExecutor {
    let capabilities: Set<String> = ["camera.capture"]

    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        XCTAssertEqual(request.operation, "photo")
        XCTAssertEqual(request.arguments["lens"]?.stringValue, "front")
        if case .object(let options) = request.arguments["options"] {
            XCTAssertEqual(options["flash"]?.boolValue, false)
            XCTAssertEqual(options["quality"]?.numberValue, 0.9)
        } else {
            XCTFail("Expected structured camera options")
        }
        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: [
                "media": [
                    "ref": "local://photo-1",
                    "width": 1920,
                    "height": 1080
                ]
            ]
        )
    }
}

private struct DeniedExecutor: BodyActionExecutor {
    let capabilities: Set<String> = ["device.open_url"]

    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        throw BodyActionError.operationDenied(request.operation)
    }
}

private func jsonResponse(_ object: Any, status: Int = 200) -> RuntimeHTTPResponse {
    RuntimeHTTPResponse(
        statusCode: status,
        data: try! JSONSerialization.data(withJSONObject: object)
    )
}

private func client(
    broker: BodyActionBroker,
    transport: RecordingRuntimeTransport
) -> RuntimeActionClient {
    RuntimeActionClient(
        configuration: RuntimeActionClientConfiguration(
            baseURL: URL(string: "https://runtime.invalid")!,
            deviceCredential: "edv1.device.credential-secret",
            deviceLabel: "Dedicated Body"
        ),
        transport: transport,
        broker: broker
    )
}

final class RuntimeActionClientTests: XCTestCase {
    func testCapabilitySyncUsesScopedBearerAndStructuredBodyAgentSnapshot() async throws {
        let broker = BodyActionBroker()
        try await broker.setAvailability(.available, for: "camera.capture")
        let transport = RecordingRuntimeTransport(responses: [jsonResponse(["ok": true])])
        let runtime = client(broker: broker, transport: transport)

        try await runtime.syncCapabilities(metadata: [
            "install_mode": "native",
            "dedicated": true
        ])

        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/body/device")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer edv1.device.credential-secret")

        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let capabilities = try XCTUnwrap(object["capabilities"] as? [String: Any])
        let bodyAgent = try XCTUnwrap(capabilities["body_agent"] as? [[String: Any]])
        let camera = try XCTUnwrap(bodyAgent.first(where: { $0["id"] as? String == "camera.capture" }))
        XCTAssertEqual(camera["availability"] as? String, "available")
        let metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["dedicated"] as? Bool, true)
    }

    func testOneCycleClaimsExecutesAndCompletesStructuredAction() async throws {
        let actionID = UUID()
        let claim: [String: Any] = [
            "ok": true,
            "action": [
                "id": actionID.uuidString.lowercased(),
                "device_id": "body-1",
                "actor_id": "actor-1",
                "capability": "camera.capture",
                "operation": "photo",
                "arguments": [
                    "lens": "front",
                    "options": ["flash": false, "quality": 0.9]
                ],
                "state": "claimed"
            ]
        ]
        let transport = RecordingRuntimeTransport(responses: [
            jsonResponse(claim),
            jsonResponse(["ok": true])
        ])
        let broker = BodyActionBroker()
        try await broker.register(StructuredCameraExecutor())
        try await broker.setAvailability(.available, for: "camera.capture")
        let runtime = client(broker: broker, transport: transport)

        let result = try await runtime.runOneCycle()
        XCTAssertEqual(result.outcome, RuntimeActionCycleResult.Outcome.completed)
        XCTAssertEqual(result.actionID, actionID)

        let requests = await transport.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/v1/body/actions/claim",
            "/api/v1/body/actions/\(actionID.uuidString.lowercased())/complete"
        ])
        let completionBody = try XCTUnwrap(requests[1].httpBody)
        let completion = try XCTUnwrap(JSONSerialization.jsonObject(with: completionBody) as? [String: Any])
        XCTAssertEqual(completion["success"] as? Bool, true)
        let output = try XCTUnwrap(completion["result"] as? [String: Any])
        let media = try XCTUnwrap(output["media"] as? [String: Any])
        XCTAssertEqual(media["ref"] as? String, "local://photo-1")
        XCTAssertEqual((media["width"] as? NSNumber)?.doubleValue, 1920)
    }

    func testExecutorFailureIsReportedToRuntimeInsteadOfEscapingAsCompleted() async throws {
        let actionID = UUID()
        let transport = RecordingRuntimeTransport(responses: [
            jsonResponse([
                "ok": true,
                "action": [
                    "id": actionID.uuidString.lowercased(),
                    "device_id": "body-1",
                    "actor_id": "actor-1",
                    "capability": "device.open_url",
                    "operation": "open",
                    "arguments": ["url": "https://example.invalid"],
                    "state": "claimed"
                ]
            ]),
            jsonResponse(["ok": true])
        ])
        let broker = BodyActionBroker()
        try await broker.register(DeniedExecutor())
        try await broker.setAvailability(.available, for: "device.open_url")
        let runtime = client(broker: broker, transport: transport)

        let result = try await runtime.runOneCycle()
        XCTAssertEqual(result.outcome, RuntimeActionCycleResult.Outcome.failed)

        let requests = await transport.requests()
        let completionBody = try XCTUnwrap(requests[1].httpBody)
        let completion = try XCTUnwrap(JSONSerialization.jsonObject(with: completionBody) as? [String: Any])
        XCTAssertEqual(completion["success"] as? Bool, false)
        XCTAssertNotNil(completion["error"] as? String)
    }

    func testIdleCycleDoesNotInventWork() async throws {
        let transport = RecordingRuntimeTransport(responses: [
            jsonResponse(["ok": true, "action": NSNull()])
        ])
        let broker = BodyActionBroker()
        let runtime = client(broker: broker, transport: transport)

        let result = try await runtime.runOneCycle()
        XCTAssertEqual(result.outcome, RuntimeActionCycleResult.Outcome.idle)
        XCTAssertNil(result.actionID)
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
    }
}
