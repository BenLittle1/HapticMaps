import CoreLocation
import Foundation
import Combine

class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationUpdating: Bool = false
    
    private let locationManager: CLLocationManager
    
    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
    }
    
    // For dependency injection in tests
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // User needs to go to settings to enable location
            break
        case .authorizedWhenInUse:
            // Request always authorization for background navigation
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            // Already have the best permission
            break
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        guard !isLocationUpdating else { return }
        
        locationManager.startUpdatingLocation()
        isLocationUpdating = true
    }
    
    func stopLocationUpdates() {
        guard isLocationUpdating else { return }
        
        locationManager.stopUpdatingLocation()
        isLocationUpdating = false
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if the location is recent and accurate
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge < 5.0 && location.horizontalAccuracy < 100 {
            DispatchQueue.main.async {
                self.currentLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // Stop updating on significant errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied, .locationUnknown, .network:
                stopLocationUpdates()
            default:
                break
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, can start location updates if requested
            break
        case .denied, .restricted:
            // Permission denied, stop any ongoing updates
            stopLocationUpdates()
        case .notDetermined:
            // Initial state, no action needed
            break
        @unknown default:
            break
        }
    }
}