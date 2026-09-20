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

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000
    }
    func requestPermission() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.startUpdatingLocation()
        default: break
        }
    }
    func stopUpdatingLocation() { manager.stopUpdatingLocation() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
            location = nil
            locationName = ""
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let value = locations.last, value.horizontalAccuracy >= 0,
              abs(value.timestamp.timeIntervalSinceNow) < 300 else { return }
        location = value
        if lastGeocoded.map({ $0.distance(from: value) < 1000 }) == true { return }
        lastGeocoded = value
        geocoder.reverseGeocodeLocation(value) { [weak self] places, _ in
            DispatchQueue.main.async {
                self?.locationName = places?.first?.locality ?? ""
                UserDefaults(suiteName: "group.com.khouryg.fryday")?.set(self?.locationName ?? "", forKey: "locationName")
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
