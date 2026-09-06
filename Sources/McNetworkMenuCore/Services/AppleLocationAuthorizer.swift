@preconcurrency import CoreLocation
import Foundation

public enum LocationAuthorizationMapper {
    public static func map(_ status: CLAuthorizationStatus) -> LocationPermissionState {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}

@MainActor
public final class AppleLocationAuthorizer: NSObject, LocationAuthorizing, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var pendingContinuation: CheckedContinuation<LocationPermissionState, Never>?

    public override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    public func currentStatus() async -> LocationPermissionState {
        LocationAuthorizationMapper.map(manager.authorizationStatus)
    }

    public func requestAuthorization() async -> LocationPermissionState {
        let current = LocationAuthorizationMapper.map(manager.authorizationStatus)
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            pendingContinuation?.resume(returning: .notDetermined)
            pendingContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = LocationAuthorizationMapper.map(manager.authorizationStatus)
        guard status != .notDetermined, let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        continuation.resume(returning: status)
    }
}
