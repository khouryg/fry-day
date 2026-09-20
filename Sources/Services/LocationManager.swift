import Foundation
import CoreLocation
import UIKit

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationName = ""
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocoded: CLLocation?
    private var geocodingLocation: CLLocation?
    private var geocodeGeneration = UUID()
    private var geocodeRetryAfter = Date.distantPast
    private var wantsUpdates = false
    private var isUpdating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000
    }
    func requestPermission() {
        wantsUpdates = true
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: startIfNeeded()
        default: break
        }
    }
    private func startIfNeeded() {
        guard wantsUpdates, !isUpdating else { return }
        isUpdating = true
        manager.startUpdatingLocation()
    }
    func stopUpdatingLocation() {
        wantsUpdates = false
        isUpdating = false
        manager.stopUpdatingLocation()
        geocodeGeneration = UUID()
        geocodingLocation = nil
        geocoder.cancelGeocode()
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startIfNeeded()
        } else {
            isUpdating = false
            manager.stopUpdatingLocation()
            location = nil
            locationName = ""
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsUpdates, let value = locations.last, value.horizontalAccuracy >= 0,
              abs(value.timestamp.timeIntervalSinceNow) < 300 else { return }
        location = value
        if lastGeocoded.map({ $0.distance(from: value) < 1000 }) == true { return }
        guard Date() >= geocodeRetryAfter else { return }
        if geocodingLocation.map({ $0.distance(from: value) < 1000 }) == true { return }
        geocoder.cancelGeocode()
        geocodingLocation = value
        let generation = UUID()
        geocodeGeneration = generation
        geocoder.reverseGeocodeLocation(value) { [weak self] places, error in
            DispatchQueue.main.async {
                guard let self, self.wantsUpdates, self.geocodeGeneration == generation else { return }
                self.geocodingLocation = nil
                guard error == nil else {
                    self.geocodeRetryAfter = Date().addingTimeInterval(60)
                    return
                }
                self.lastGeocoded = value
                self.locationName = places?.first?.locality ?? ""
                UserDefaults(suiteName: "group.com.khouryg.fryday")?.set(self.locationName, forKey: "locationName")
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
