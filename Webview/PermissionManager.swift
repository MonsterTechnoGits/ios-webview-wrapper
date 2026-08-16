import AVFoundation
import CoreLocation
import Foundation
import Photos

enum PermissionType: String {
    case camera
    case microphone
    case photos
    case location
}

@MainActor
final class PermissionManager: NSObject, CLLocationManagerDelegate {
    private var locationContinuation: CheckedContinuation<String, Never>?
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    func requestPermission(_ type: PermissionType) async -> String {
        switch type {
        case .camera:
            return await requestAVPermission(for: .video)
        case .microphone:
            return await requestAVPermission(for: .audio)
        case .photos:
            return await requestPhotosPermission()
        case .location:
            return await requestLocationPermission()
        }
    }

    private func requestAVPermission(for mediaType: AVMediaType) async -> String {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .authorized:
            return "authorized"
        case .denied, .restricted:
            return "denied"
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: mediaType)
            return granted ? "authorized" : "denied"
        @unknown default:
            return "unknown"
        }
    }

    private func requestPhotosPermission() async -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return "authorized"
        case .denied, .restricted:
            return "denied"
        case .notDetermined:
            let next = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return (next == .authorized || next == .limited) ? "authorized" : "denied"
        @unknown default:
            return "unknown"
        }
    }

    private func requestLocationPermission() async -> String {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return "authorized"
        case .denied, .restricted:
            return "denied"
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.locationContinuation = continuation
                self.locationManager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return "unknown"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = locationContinuation else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            continuation.resume(returning: "authorized")
            locationContinuation = nil
        case .denied, .restricted:
            continuation.resume(returning: "denied")
            locationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            continuation.resume(returning: "unknown")
            locationContinuation = nil
        }
    }
}
