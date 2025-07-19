import CoreLocation
import Foundation

protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationUpdating: Bool { get }
    
    func requestLocationPermission()
    func startLocationUpdates()
    func stopLocationUpdates()
}