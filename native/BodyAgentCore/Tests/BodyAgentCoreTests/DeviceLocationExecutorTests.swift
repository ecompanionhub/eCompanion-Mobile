import Foundation
import XCTest
@testable import BodyAgentCore

private struct StubDeviceLocationDriver: DeviceLocationDriver {
    let result: Result<DeviceLocationSnapshot, BodyActionError>

    func currentLocation() async throws -> DeviceLocationSnapshot {
        try result.get()
    }
}

final class DeviceLocationExecutorTests: XCTestCase {
    func testCurrentLocationReturnsStructuredSensorSnapshot() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_788_650_000.125)
        let executor = DeviceLocationActionExecutor(driver: StubDeviceLocationDriver(result: .success(
            DeviceLocationSnapshot(
                latitude: 51.8133,
                longitude: 4.6901,
                altitudeMeters: 3.5,
                horizontalAccuracyMeters: 8.25,
                verticalAccuracyMeters: 12.0,
                timestamp: timestamp
            )
        )))

        let result = try await executor.execute(BodyActionRequest(
            capability: "device.location",
            operation: "current"
        ))

        XCTAssertEqual(result.output["latitude"]?.numberValue, 51.8133)
        XCTAssertEqual(result.output["longitude"]?.numberValue, 4.6901)
        XCTAssertEqual(result.output["altitude_meters"]?.numberValue, 3.5)
        XCTAssertEqual(result.output["horizontal_accuracy_meters"]?.numberValue, 8.25)
        XCTAssertEqual(result.output["vertical_accuracy_meters"]?.numberValue, 12.0)
        XCTAssertEqual(result.output["timestamp_unix_ms"]?.numberValue, timestamp.timeIntervalSince1970 * 1_000)
    }

    func testLocationPermissionFailureRemainsMachineReadable() async throws {
        let executor = DeviceLocationActionExecutor(driver: StubDeviceLocationDriver(result: .failure(
            .executionFailed("BODY_ACTION_LOCATION_PERMISSION_DENIED")
        )))

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.location",
                operation: "current"
            ))
            XCTFail("Denied location permission must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .executionFailed("BODY_ACTION_LOCATION_PERMISSION_DENIED"))
        }
    }

    func testLocationRejectsArgumentsAndUnknownOperations() async throws {
        let snapshot = DeviceLocationSnapshot(
            latitude: 0,
            longitude: 0,
            altitudeMeters: 0,
            horizontalAccuracyMeters: 1,
            verticalAccuracyMeters: 1,
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let executor = DeviceLocationActionExecutor(driver: StubDeviceLocationDriver(result: .success(snapshot)))

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.location",
                operation: "current",
                arguments: ["background": .bool(true)]
            ))
            XCTFail("Location action must reject undeclared tracking arguments")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .invalidArguments("BODY_ACTION_ARGUMENT_UNEXPECTED"))
        }

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.location",
                operation: "track"
            ))
            XCTFail("Background tracking operation must not exist")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .operationDenied("track"))
        }
    }

    func testLocationRejectsInvalidCoordinatesFromDriver() async throws {
        let executor = DeviceLocationActionExecutor(driver: StubDeviceLocationDriver(result: .success(
            DeviceLocationSnapshot(
                latitude: 123,
                longitude: 0,
                altitudeMeters: 0,
                horizontalAccuracyMeters: 1,
                verticalAccuracyMeters: 1,
                timestamp: Date()
            )
        )))

        do {
            _ = try await executor.execute(BodyActionRequest(
                capability: "device.location",
                operation: "current"
            ))
            XCTFail("Invalid sensor coordinates must fail closed")
        } catch let error as BodyActionError {
            XCTAssertEqual(error, .executionFailed("BODY_ACTION_LOCATION_INVALID"))
        }
    }
}
