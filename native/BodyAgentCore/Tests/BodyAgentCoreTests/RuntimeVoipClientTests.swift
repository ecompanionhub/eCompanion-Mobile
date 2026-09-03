import Foundation
import XCTest
@testable import BodyAgentCore

private actor VoipRecordingTransport: RuntimeHTTPTransport {
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

final class RuntimeVoipClientTests: XCTestCase {
    private func makeClient(transport: VoipRecordingTransport) -> RuntimeActionClient {
        RuntimeActionClient(
            configuration: RuntimeActionClientConfiguration(
                baseURL: URL(string: "https://runtime.invalid")!,
                deviceCredential: "edv1.credential.secret",
                deviceLabel: "Native iPhone"
            ),
            transport: transport,
            broker: BodyActionBroker()
        )
    }

    func testRegisterVoipUsesBearerPutAndCanonicalPayload() async throws {
        let transport = VoipRecordingTransport(responses: [
            RuntimeHTTPResponse(statusCode: 200, data: Data("{\"ok\":true}".utf8))
        ])
        let client = makeClient(transport: transport)
        let token = String(repeating: "ab", count: 32)

        try await client.registerVoip(
            RuntimeVoipRegistration(
                tokenHex: token.uppercased(),
                bundleID: "app.ecompanion.body",
                environment: .production
            )
        )

        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/body/voip")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer edv1.credential.secret")
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["token"] as? String, token)
        XCTAssertEqual(object["bundleId"] as? String, "app.ecompanion.body")
        XCTAssertEqual(object["environment"] as? String, "production")
    }

    func testClearVoipUsesAuthenticatedDeleteWithoutBody() async throws {
        let transport = VoipRecordingTransport(responses: [
            RuntimeHTTPResponse(statusCode: 200, data: Data("{\"ok\":true}".utf8))
        ])
        let client = makeClient(transport: transport)

        try await client.clearVoip()

        let requests = await transport.requests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/body/voip")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer edv1.credential.secret")
        XCTAssertNil(request.httpBody)
    }

    func testRegisterVoipRejectsNonHexTokenBeforeNetwork() async throws {
        let transport = VoipRecordingTransport(responses: [])
        let client = makeClient(transport: transport)

        do {
            try await client.registerVoip(
                RuntimeVoipRegistration(
                    tokenHex: String(repeating: "zz", count: 32),
                    bundleID: "app.ecompanion.body",
                    environment: .sandbox
                )
            )
            XCTFail("Non-hex token must be rejected")
        } catch let error as RuntimeActionClientError {
            XCTAssertEqual(error, .invalidVoipToken)
        }
        XCTAssertTrue(await transport.requests().isEmpty)
    }

    func testRegisterVoipRejectsInvalidBundleBeforeNetwork() async throws {
        let transport = VoipRecordingTransport(responses: [])
        let client = makeClient(transport: transport)

        do {
            try await client.registerVoip(
                RuntimeVoipRegistration(
                    tokenHex: String(repeating: "ab", count: 32),
                    bundleID: "app..ecompanion.body",
                    environment: .sandbox
                )
            )
            XCTFail("Invalid bundle must be rejected")
        } catch let error as RuntimeActionClientError {
            XCTAssertEqual(error, .invalidVoipBundleID)
        }
        XCTAssertTrue(await transport.requests().isEmpty)
    }
}
