import XCTest
@testable import BodyAgentCore

private struct EchoExecutor: BodyActionExecutor {
    let capabilities: Set<String>

    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: ["operation": request.operation]
        )
    }
}

final class BodyAgentCoreTests: XCTestCase {
    func testBrokerFailsClosedUntilCapabilityIsAvailable() async throws {
        let broker = BodyActionBroker()
        let request = BodyActionRequest(capability: "audio.capture", operation: "start")

        do {
            _ = try await broker.execute(request)
            XCTFail("Unavailable capability must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .capabilityUnavailable("audio.capture"))
        }

        try await broker.register(EchoExecutor(capabilities: ["audio.capture"]))
        try await broker.setAvailability(.available, for: "audio.capture")
        let result = try await broker.execute(request)
        XCTAssertEqual(result.capability, "audio.capture")
        XCTAssertEqual(result.output["operation"], "start")
    }

    func testUnknownAndElevatedCapabilitiesAreNeverImplicitlyGranted() async throws {
        let broker = BodyActionBroker()

        do {
            try await broker.setAvailability(.available, for: "device.magic")
            XCTFail("Unknown capability must be rejected")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .unknownCapability("device.magic"))
        }

        let elevated = try XCTUnwrap(
            await broker.snapshot().first(where: { $0.id == "elevated.springboard" })
        )
        XCTAssertEqual(elevated.tier, .elevated)
        XCTAssertEqual(elevated.availability, .unavailable)
    }

    func testCommunicationIntentMapsToGenericCapabilities() {
        XCTAssertEqual(
            CommunicationIntent(
                kind: .message,
                target: .init(transport: "telegram", address: "peer")
            ).requiredCapability,
            "message.send"
        )
        XCTAssertEqual(
            CommunicationIntent(
                kind: .videoCall,
                target: .init(transport: "runtime", address: "owner")
            ).requiredCapability,
            "call.video"
        )
    }
}
