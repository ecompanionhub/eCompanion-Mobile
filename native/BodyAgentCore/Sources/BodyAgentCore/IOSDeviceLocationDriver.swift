#if os(iOS)
import CoreLocation
import Foundation

struct IOSDeviceLocationDriver: DeviceLocationDriver {
    func currentLocation() async throws -> DeviceLocationSnapshot {
        try await IOSLocationRequest.current()
    }
}

@MainActor
private final class IOSLocationRequest: NSObject {
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
            handleAuthorizationState()
        }
    }

    private func handleAuthorizationState() {
        guard continuation != nil else { return }
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

    private func finish(_ result: Result<DeviceLocationSnapshot, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }
}

extension IOSLocationRequest: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.handleAuthorizationState()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.max(by: { $0.timestamp < $1.timestamp }) else {
            Task { @MainActor [weak self] in
                self?.finish(.failure(BodyActionError.executionFailed("BODY_ACTION_LOCATION_EMPTY")))
            }
            return
        }

        let snapshot = DeviceLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: location.altitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            verticalAccuracyMeters: location.verticalAccuracy,
            timestamp: location.timestamp
        )
        Task { @MainActor [weak self] in
            self?.finish(.success(snapshot))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code: String
        if let coreLocationError = error as? CLError, coreLocationError.code == .denied {
            code = "BODY_ACTION_LOCATION_PERMISSION_DENIED"
        } else {
            code = "BODY_ACTION_LOCATION_UNAVAILABLE"
        }
        Task { @MainActor [weak self] in
            self?.finish(.failure(BodyActionError.executionFailed(code)))
        }
    }
}
#endif
