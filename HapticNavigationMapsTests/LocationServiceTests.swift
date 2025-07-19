import XCTest
import CoreLocation
import Combine
@testable import HapticNavigationMaps

class LocationServiceTests: XCTestCase {
    var locationService: LocationService!
    var mockLocationManager: MockCLLocationManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLocationManager = MockCLLocationManager()
        locationService = LocationService(locationManager: mockLocationManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        locationService = nil
        mockLocationManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testLocationServiceInitialization() {
        XCTAssertNotNil(locationService)
        XCTAssertEqual(locationService.authorizationStatus, .notDetermined)
        XCTAssertFalse(locationService.isLocationUpdating)
        XCTAssertFalse(locationService.isBackgroundLocationEnabled)
        XCTAssertFalse(locationService.hasRequestedAlwaysPermission)
        XCTAssertNil(locationService.locationError)
        XCTAssertTrue(locationService.isGPSSignalStrong)
    }
    
    func testRequestLocationPermissionWhenNotDetermined() {
        mockLocationManager.authorizationStatus = .notDetermined
        
        locationService.requestLocationPermission()
        
        XCTAssertTrue(mockLocationManager.requestWhenInUseAuthorizationCalled)
        XCTAssertNil(locationService.locationError)
    }
    
    func testStartLocationUpdatesWithAuthorizedStatus() {
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        
        locationService.startLocationUpdates()
        
        XCTAssertTrue(mockLocationManager.startUpdatingLocationCalled)
        XCTAssertTrue(locationService.isLocationUpdating)
        XCTAssertNil(locationService.locationError)
    }
    
    func testStopLocationUpdates() {
        locationService.startLocationUpdates()
        locationService.stopLocationUpdates()
        
        XCTAssertTrue(mockLocationManager.stopUpdatingLocationCalled)
        XCTAssertFalse(locationService.isLocationUpdating)
        XCTAssertNil(locationService.locationError)
    }
    
    // MARK: - Error Handling Tests
    
    func testLocationPermissionDeniedError() {
        mockLocationManager.authorizationStatus = .denied
        
        let expectation = XCTestExpectation(description: "Location error set")
        locationService.$locationError
            .sink { error in
                if error == .permissionDenied {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.requestLocationPermission()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .permissionDenied)
    }
    
    func testLocationPermissionRestrictedError() {
        mockLocationManager.authorizationStatus = .restricted
        
        let expectation = XCTestExpectation(description: "Location error set")
        locationService.$locationError
            .sink { error in
                if error == .permissionRestricted {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.requestLocationPermission()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .permissionRestricted)
    }
    
    func testStartLocationUpdatesWithoutPermission() {
        mockLocationManager.authorizationStatus = .denied
        
        locationService.startLocationUpdates()
        
        XCTAssertFalse(mockLocationManager.startUpdatingLocationCalled)
        XCTAssertFalse(locationService.isLocationUpdating)
        XCTAssertEqual(locationService.locationError, .permissionDenied)
    }
    
    func testLocationAccuracyTooLowError() {
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        
        let expectation = XCTestExpectation(description: "Accuracy too low error")
        locationService.$locationError
            .sink { error in
                if error == .accuracyTooLow {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate receiving a location with poor accuracy
        let poorLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 600, // Very poor accuracy
            verticalAccuracy: 0,
            timestamp: Date()
        )
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [poorLocation])
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .accuracyTooLow)
    }
    
    func testStaleLocationError() {
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        
        let expectation = XCTestExpectation(description: "Stale location error")
        locationService.$locationError
            .sink { error in
                if error == .staleLocation {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate receiving an old location
        let staleLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 0,
            timestamp: Date().addingTimeInterval(-10) // 10 seconds old
        )
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [staleLocation])
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .staleLocation)
    }
    
    func testGoodLocationClearsError() {
        // First set an error
        locationService.startLocationUpdates()
        let poorLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 600,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        locationService.locationManager(mockLocationManager, didUpdateLocations: [poorLocation])
        XCTAssertEqual(locationService.locationError, .accuracyTooLow)
        
        // Then provide a good location
        let goodLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        
        let expectation = XCTestExpectation(description: "Error cleared")
        locationService.$locationError
            .sink { error in
                if error == nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [goodLocation])
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(locationService.locationError)
        XCTAssertEqual(locationService.currentLocation, goodLocation)
    }
    
    // MARK: - Location Manager Delegate Error Tests
    
    func testLocationManagerDidFailWithPermissionDeniedError() {
        let error = CLError(.denied)
        
        let expectation = XCTestExpectation(description: "Permission denied error handled")
        locationService.$locationError
            .sink { locationError in
                if locationError == .permissionDenied {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(mockLocationManager, didFailWithError: error)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .permissionDenied)
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    func testLocationManagerDidFailWithRestrictedError() {
        let error = CLError(.locationUnknown)
        
        let expectation = XCTestExpectation(description: "Location unavailable error handled")
        locationService.$locationError
            .sink { locationError in
                if locationError == .locationUnavailable {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(mockLocationManager, didFailWithError: error)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .locationUnavailable)
    }
    
    func testLocationManagerDidFailWithNetworkError() {
        let error = CLError(.network)
        
        let expectation = XCTestExpectation(description: "Network error handled")
        locationService.$locationError
            .sink { locationError in
                if locationError == .networkError {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(mockLocationManager, didFailWithError: error)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.locationError, .networkError)
    }
    
    // MARK: - Authorization Change Tests
    
    func testLocationManagerDidChangeAuthorizationToAuthorized() {
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        
        let expectation = XCTestExpectation(description: "Authorization status updated")
        locationService.$authorizationStatus
            .sink { status in
                if status == .authorizedWhenInUse {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManagerDidChangeAuthorization(mockLocationManager)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.authorizationStatus, .authorizedWhenInUse)
    }
    
    func testLocationManagerDidChangeAuthorizationToDenied() {
        // First authorize
        mockLocationManager.authorizationStatus = .authorizedWhenInUse
        locationService.startLocationUpdates()
        XCTAssertTrue(locationService.isLocationUpdating)
        
        // Then deny
        mockLocationManager.authorizationStatus = .denied
        
        let expectation = XCTestExpectation(description: "Location updates stopped")
        locationService.$isLocationUpdating
            .sink { isUpdating in
                if !isUpdating {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManagerDidChangeAuthorization(mockLocationManager)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(locationService.authorizationStatus, .denied)
        XCTAssertFalse(locationService.isLocationUpdating)
    }
    
    // MARK: - GPS Signal Monitoring Tests
    
    func testGPSSignalLossDetection() {
        locationService.startLocationUpdates()
        
        // Simulate GPS signal loss by not providing location updates for extended period
        let expectation = XCTestExpectation(description: "GPS signal loss detected")
        
        // Listen for GPS signal lost notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name("GPSSignalLost"), object: nil, queue: .main) { _ in
            expectation.fulfill()
        }
        
        // Simulate time passing without location updates (this would normally take 30+ seconds)
        // For testing, we can manually trigger the GPS signal check
        locationService.setValue(Date().addingTimeInterval(-35), forKey: "lastLocationUpdateTime")
        
        // Manually trigger GPS signal health check
        let mirror = Mirror(reflecting: locationService!)
        if let checkMethod = mirror.children.first(where: { $0.label == "checkGPSSignalHealth" })?.value as? () -> Void {
            checkMethod()
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(locationService.isGPSSignalStrong)
        XCTAssertEqual(locationService.locationError, .gpsSignalLost)
    }
    
    // MARK: - Recovery Mechanism Tests
    
    func testLocationUpdateRetryMechanism() {
        locationService.startLocationUpdates()
        
        // Simulate a recoverable error
        let error = CLError(.locationUnknown)
        locationService.locationManager(mockLocationManager, didFailWithError: error)
        
        // The service should attempt recovery
        XCTAssertEqual(locationService.locationError, .locationUnavailable)
        
        // After retry, if we get a good location, error should clear
        let goodLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        
        let expectation = XCTestExpectation(description: "Recovery successful")
        locationService.$locationError
            .sink { error in
                if error == nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [goodLocation])
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(locationService.locationError)
        XCTAssertEqual(locationService.currentLocation, goodLocation)
    }
}

// MARK: - Mock CLLocationManager

class MockCLLocationManager: CLLocationManager {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var requestWhenInUseAuthorizationCalled = false
    var requestAlwaysAuthorizationCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    
    override var authorizationStatus: CLAuthorizationStatus {
        return authorizationStatus
    }
    
    override func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCalled = true
    }
    
    override func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCalled = true
    }
    
    override func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }
    
    override func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
}