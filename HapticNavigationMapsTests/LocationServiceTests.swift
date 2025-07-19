import XCTest
import CoreLocation
@testable import HapticNavigationMaps

class MockCLLocationManager: CLLocationManager {
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockLocation: CLLocation?
    var didRequestWhenInUse = false
    var didRequestAlways = false
    var didStartUpdatingLocation = false
    var didStopUpdatingLocation = false
    
    override var authorizationStatus: CLAuthorizationStatus {
        return mockAuthorizationStatus
    }
    
    override func requestWhenInUseAuthorization() {
        didRequestWhenInUse = true
    }
    
    override func requestAlwaysAuthorization() {
        didRequestAlways = true
    }
    
    override func startUpdatingLocation() {
        didStartUpdatingLocation = true
    }
    
    override func stopUpdatingLocation() {
        didStopUpdatingLocation = true
    }
    
    // Helper method to simulate location updates
    func simulateLocationUpdate(_ location: CLLocation) {
        delegate?.locationManager?(self, didUpdateLocations: [location])
    }
    
    // Helper method to simulate authorization changes
    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        mockAuthorizationStatus = status
        delegate?.locationManagerDidChangeAuthorization?(self)
    }
    
    // Helper method to simulate location errors
    func simulateLocationError(_ error: Error) {
        delegate?.locationManager?(self, didFailWithError: error)
    }
}

class LocationServiceTests: XCTestCase {
    var locationService: LocationService!
    var mockLocationManager: MockCLLocationManager!
    
    override func setUp() {
        super.setUp()
        mockLocationManager = MockCLLocationManager()
        locationService = LocationService(locationManager: mockLocationManager)
    }
    
    override func tearDown() {
        locationService = nil
        mockLocationManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNil(locationService.currentLocation)
        XCTAssertEqual(locationService.authorizationStatus, .notDetermined)
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    // MARK: - Permission Request Tests
    
    func testRequestLocationPermissionWhenNotDetermined() {
        mockLocationManager.mockAuthorizationStatus = .notDetermined
        locationService.requestLocationPermission()
        
        XCTAssertTrue(mockLocationManager.didRequestWhenInUse)
        XCTAssertFalse(mockLocationManager.didRequestAlways)
    }
    
    func testRequestLocationPermissionWhenAuthorizedWhenInUse() {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.requestLocationPermission()
        
        XCTAssertFalse(mockLocationManager.didRequestWhenInUse)
        XCTAssertTrue(mockLocationManager.didRequestAlways)
    }
    
    func testRequestLocationPermissionWhenDenied() {
        mockLocationManager.mockAuthorizationStatus = .denied
        locationService.requestLocationPermission()
        
        XCTAssertFalse(mockLocationManager.didRequestWhenInUse)
        XCTAssertFalse(mockLocationManager.didRequestAlways)
    }
    
    func testRequestLocationPermissionWhenAlreadyAuthorizedAlways() {
        mockLocationManager.mockAuthorizationStatus = .authorizedAlways
        locationService.requestLocationPermission()
        
        XCTAssertFalse(mockLocationManager.didRequestWhenInUse)
        XCTAssertFalse(mockLocationManager.didRequestAlways)
    }
    
    // MARK: - Location Updates Tests
    
    func testStartLocationUpdatesWithPermission() {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        
        XCTAssertTrue(mockLocationManager.didStartUpdatingLocation)
        XCTAssertTrue(locationService.isLocationUpdating)
    }
    
    func testStartLocationUpdatesWithoutPermission() {
        mockLocationManager.mockAuthorizationStatus = .denied
        locationService.startLocationUpdates()
        
        XCTAssertFalse(mockLocationManager.didStartUpdatingLocation)
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    func testStopLocationUpdates() {
        // First start updates
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        
        // Then stop them
        locationService.stopLocationUpdates()
        
        XCTAssertTrue(mockLocationManager.didStopUpdatingLocation)
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    func testStartLocationUpdatesWhenAlreadyUpdating() {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        
        // Reset the flag
        mockLocationManager.didStartUpdatingLocation = false
        
        // Try to start again
        locationService.startLocationUpdates()
        
        // Should not call startUpdatingLocation again
        XCTAssertFalse(mockLocationManager.didStartUpdatingLocation)
    }
    
    // MARK: - Delegate Method Tests
    
    func testLocationUpdateWithValidLocation() {
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let expectation = XCTestExpectation(description: "Location updated")
        
        // Use a small delay to allow for async updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.locationService.currentLocation != nil {
                expectation.fulfill()
            }
        }
        
        mockLocationManager.simulateLocationUpdate(testLocation)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(locationService.currentLocation)
        if let currentLocation = locationService.currentLocation {
            XCTAssertEqual(currentLocation.coordinate.latitude, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(currentLocation.coordinate.longitude, -122.4194, accuracy: 0.0001)
        }
    }
    
    func testLocationUpdateWithInaccurateLocation() {
        // Create a location with poor accuracy (> 100m)
        let testLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 150, // Poor accuracy
            verticalAccuracy: 0,
            timestamp: Date()
        )
        
        mockLocationManager.simulateLocationUpdate(testLocation)
        
        // Should not update current location due to poor accuracy
        XCTAssertNil(locationService.currentLocation)
    }
    
    func testAuthorizationStatusChange() {
        let expectation = XCTestExpectation(description: "Authorization status updated")
        
        // Use a small delay to allow for async updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.locationService.authorizationStatus == .authorizedWhenInUse {
                expectation.fulfill()
            }
        }
        
        mockLocationManager.simulateAuthorizationChange(.authorizedWhenInUse)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(locationService.authorizationStatus, .authorizedWhenInUse)
    }
    
    func testAuthorizationDeniedStopsLocationUpdates() {
        // First start location updates
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        XCTAssertTrue(locationService.isLocationUpdating)
        
        // Then simulate authorization being denied
        mockLocationManager.simulateAuthorizationChange(.denied)
        
        // Should stop location updates
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    func testLocationManagerError() {
        let error = CLError(.denied)
        
        // Start location updates first
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        XCTAssertTrue(locationService.isLocationUpdating)
        
        // Simulate error
        mockLocationManager.simulateLocationError(error)
        
        // Should stop location updates on denied error
        XCTAssertFalse(locationService.isLocationUpdating)
    }
}