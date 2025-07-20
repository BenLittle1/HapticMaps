import CoreLocation
import Foundation

protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationUpdating: Bool { get }
    var isBackgroundLocationEnabled: Bool { get }
    var hasRequestedAlwaysPermission: Bool { get }
    var locationError: LocationError? { get }
    var isGPSSignalStrong: Bool { get }
    var locationAccuracy: CLLocationAccuracy { get }
    
    // Performance monitoring
    var currentNavigationState: NavigationState { get }
    var currentUpdateFrequency: Double { get }
    
    func requestLocationPermission()
    func requestAlwaysPermissionIfNeeded()
    func startLocationUpdates()
    func stopLocationUpdates()
    func updateNavigationState(_ state: NavigationState)
}