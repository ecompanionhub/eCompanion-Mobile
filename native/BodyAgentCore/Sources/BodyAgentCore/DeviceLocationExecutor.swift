import Foundation

struct DeviceLocationSnapshot: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
    let horizontalAccuracyMeters: Double
    let verticalAccuracyMeters: Double
    let timestamp: Date
}

protocol DeviceLocationDriver: Sendable {
    func currentLocation() async throws -> DeviceLocationSnapshot
}

struct DeviceLocationActionExecutor: BodyActionExecutor {
    let capabilities: Set<String> = ["device.location"]

    private let driver: any DeviceLocationDriver

    init(driver: any DeviceLocationDriver) {
        self.driver = driver
    }

    func execute(_ request: BodyActionRequest) async throws -> BodyActionResult {
        guard request.capability == "device.location" else {
            throw BodyActionError.unknownCapability(request.capability)
        }
        guard request.operation == "current" else {
            throw BodyActionError.operationDenied(request.operation)
        }
        try StockActionSupport.rejectUnexpectedArguments(request.arguments, allowed: [])

        let location: DeviceLocationSnapshot
        do {
            location = try await driver.currentLocation()
        } catch let error as BodyActionError {
            throw error
        } catch {
            throw BodyActionError.executionFailed("BODY_ACTION_LOCATION_UNAVAILABLE")
        }

        guard location.latitude.isFinite,
              location.longitude.isFinite,
              (-90.0 ... 90.0).contains(location.latitude),
              (-180.0 ... 180.0).contains(location.longitude),
              location.altitudeMeters.isFinite,
              location.horizontalAccuracyMeters.isFinite,
              location.horizontalAccuracyMeters >= 0,
              location.verticalAccuracyMeters.isFinite else {
            throw BodyActionError.executionFailed("BODY_ACTION_LOCATION_INVALID")
        }

        return BodyActionResult(
            requestID: request.id,
            capability: request.capability,
            output: [
                "latitude": .number(location.latitude),
                "longitude": .number(location.longitude),
                "altitude_meters": .number(location.altitudeMeters),
                "horizontal_accuracy_meters": .number(location.horizontalAccuracyMeters),
                "vertical_accuracy_meters": .number(location.verticalAccuracyMeters),
                "timestamp_unix_ms": .number(location.timestamp.timeIntervalSince1970 * 1_000)
            ]
        )
    }
}
