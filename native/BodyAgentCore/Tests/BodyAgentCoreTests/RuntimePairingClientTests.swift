import Foundation
import XCTest
@testable import BodyAgentCore

private actor PairingRecordingTransport: RuntimeHTTPTransport {
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

private func pairingJSON(_ object: Any, status: Int = 200) -> RuntimeHTTPResponse {
    RuntimeHTTPResponse(
        statusCode: status,
        data: try! JSONSerialization.data(withJSONObject: object)
    )
}

final class RuntimePairingClientTests: XCTestCase {
    func testClaimUsesCanonicalPairingEndpointAndNativeDescriptor() async throws {
        let credentialID = UUID().uuidString.lowercased()
        let transport = PairingRecordingTransport(responses: [
            pairingJSON([
                "ok": true,
                "relinked": false,
                "device": [
                    "id": "ebody:iphone-test",
                    "label": "Dedicated iPhone",
                    "platform": "ios-native",
                    "assigned_actor_id": "lola"
                ],
                "credential": [
                    "id": credentialID,
                    "token": "edv1.\(credentialID).abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN",
                    "scopes": ["body.self", "body.device.write", "body.presence.write"],
                    "created_at": "2026-09-04T00:00:00.000Z"
                ]
            ])
        ])
        let client = try RuntimePairingClient(
            baseURL: URL(string: "https://runtime.invalid/")!,
            transport: transport
        )
        let result = try await client.claim(
            code: "abcd-efgh-jkmn-pqrs-tuvw",
            device: .nativeBody(id: "ebody:iphone-test", label: "Dedicated iPhone")
        )

        XCTAssertFalse(result.relinked)
        XCTAssertEqual(result.device.id, "ebody:iphone-test")
        XCTAssertEqual(result.device.assignedActorID, "lola")
        XCTAssertEqual(result.credential.id, credentialID)
        XCTAssertTrue(result.credential.scopes.contains("body.device.write"))

        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/device-pairing/claim")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["code"] as? String, "abcd-efgh-jkmn-pqrs-tuvw")
        let device = try XCTUnwrap(object["device"] as? [String: Any])
        XCTAssertEqual(device["id"] as? String, "ebody:iphone-test")
        XCTAssertEqual(device["label"] as? String, "Dedicated iPhone")
        XCTAssertEqual(device["platform"] as? String, "ios-native")
        let metadata = try XCTUnwrap(device["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["body_protocol"] as? String, "ecompanion-body-ios-v1")
        let capabilities = try XCTUnwrap(device["capabilities"] as? [String: Any])
        XCTAssertEqual(capabilities["native_callkit"] as? Bool, true)
        XCTAssertEqual(capabilities["native_pushkit"] as? Bool, true)
    }

    func testClaimSurfacesRuntimePairingErrorCode() async throws {
        let transport = PairingRecordingTransport(responses: [
            pairingJSON(["ok": false, "error": "PAIRING_GRANT_INVALID"], status: 409)
        ])
        let client = try RuntimePairingClient(
            baseURL: URL(string: "https://runtime.invalid")!,
            transport: transport
        )

        do {
            _ = try await client.claim(
                code: "expired-code",
                device: .nativeBody(id: "ebody:test")
            )
            XCTFail("Expected pairing rejection")
        } catch let error as RuntimePairingClientError {
            XCTAssertEqual(error, .runtimeRejected(status: 409, code: "PAIRING_GRANT_INVALID"))
        }
    }

    func testClaimRejectsMissingCredentialToken() async throws {
        let transport = PairingRecordingTransport(responses: [
            pairingJSON([
                "ok": true,
                "relinked": false,
                "device": ["id": "ebody:test", "label": "Body"],
                "credential": ["id": "credential-1", "token": "", "scopes": []]
            ])
        ])
        let client = try RuntimePairingClient(
            baseURL: URL(string: "https://runtime.invalid")!,
            transport: transport
        )

        do {
            _ = try await client.claim(code: "code", device: .nativeBody(id: "ebody:test"))
            XCTFail("Empty credential token must not be accepted")
        } catch let error as RuntimePairingClientError {
            XCTAssertEqual(error, .missingCredentialToken)
        }
    }

    func testEnrollmentProfileKeepsSecretOutOfProfile() async throws {
        let credentialID = "credential-1"
        let result = RuntimePairingResult(
            relinked: false,
            device: RuntimePairingDevice(
                id: "ebody:test",
                label: "Body",
                platform: "ios-native",
                assignedActorID: "actor-1"
            ),
            credential: RuntimePairingCredential(
                id: credentialID,
                token: "super-secret",
                scopes: ["body.self"],
                createdAt: nil
            )
        )
        let client = try RuntimePairingClient(baseURL: URL(string: "https://runtime.invalid")!)
        let profile = await client.enrollmentProfile(from: result)
        let encoded = try JSONEncoder().encode(profile)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(profile.credentialID, credentialID)
        XCTAssertFalse(text.contains("super-secret"))
    }
}
