#if os(iOS)
import Foundation
@preconcurrency import CoreLocation

struct IOSDeviceLocationDriver: DeviceLocationDriver {
    func currentLocation() async throws -> DeviceLocationSnapshot {
        try await IOSLocationRequest.current()
    }
}

@MainActor
private final class IOSLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<DeviceLocationSnapshot, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    static func current() async throws -> DeviceLocationSnapshot {
        let request = IOSLocationRequest()
        return try await request.start()
    }

    private func start() async throws -> DeviceLocationSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied:
                finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_PERMISSION_DENIED")))
            case .restricted:
                finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_PERMISSION_RESTRICTED")))
            @unknown default:
                finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_AUTHORIZATION_UNKNOWN")))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied:
            finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_PERMISSION_DENIED")))
        case .restricted:
            finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_PERMISSION_RESTRICTED")))
        case .notDetermined:
            break
        @unknown default:
            finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_AUTHORIZATION_UNKNOWN")))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.max(by: { $0.timestamp < $1.timestamp }) else {
            finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_EMPTY")))
            return
        }
        finish(.success(DeviceLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: location.altitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            verticalAccuracyMeters: location.verticalAccuracy,
            timestamp: location.timestamp
        )))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code: String
        if let coreLocationError = error as? CLError, coreLocationError.code == .denied {
            code = "BODY_ACTION_LOCATION_PERMISSION_DENIED"
        } else {
            code = "BODY_ACTION_LOCATION_UNAVAILABLE"
        }
        finish(.failure(BodyActionError.executionFailed(code)))
    }

    private func finish(_ result: Result<DeviceLocationSnapshot, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }
}
#endif
