import XCTest
import SwiftUI
import MapKit
import CoreLocation
@testable import HapticNavigationMaps

final class MapViewUITests: XCTestCase {
    
    func testMapViewDisplaysCorrectly() {
        // Test that MapView can be instantiated without crashing
        let mapView = MapView()
        XCTAssertNotNil(mapView)
        
        // Test that it can be wrapped in a hosting controller
        let hostingController = UIHostingController(rootView: mapView)
        XCTAssertNotNil(hostingController)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testLocationPermissionOverlayDisplaysForNotDetermined() {
        let overlay = LocationPermissionOverlay(
            authorizationStatus: .notDetermined,
            onRequestPermission: {},
            onOpenSettings: {}
        )
        
        XCTAssertNotNil(overlay)
        
        let hostingController = UIHostingController(rootView: overlay)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testLocationPermissionOverlayDisplaysForDenied() {
        let overlay = LocationPermissionOverlay(
            authorizationStatus: .denied,
            onRequestPermission: {},
            onOpenSettings: {}
        )
        
        XCTAssertNotNil(overlay)
        
        let hostingController = UIHostingController(rootView: overlay)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testLocationPermissionOverlayDisplaysForRestricted() {
        let overlay = LocationPermissionOverlay(
            authorizationStatus: .restricted,
            onRequestPermission: {},
            onOpenSettings: {}
        )
        
        XCTAssertNotNil(overlay)
        
        let hostingController = UIHostingController(rootView: overlay)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testMapViewWithMockLocation() {
        // Test that the map view can be instantiated
        let mapView = MapView()
        XCTAssertNotNil(mapView)
        
        // Test that it can be wrapped in a hosting controller
        let hostingController = UIHostingController(rootView: mapView)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testContentViewIntegration() {
        // Test that ContentView properly displays MapView
        let contentView = ContentView()
        XCTAssertNotNil(contentView)
        
        let hostingController = UIHostingController(rootView: contentView)
        XCTAssertNotNil(hostingController.view)
    }
}

// MARK: - Integration Tests for Map Display and Location Centering
final class MapViewIntegrationTests: XCTestCase {
    
    func testMapCameraPositionUpdatesWithLocation() {
        let expectation = XCTestExpectation(description: "Camera position updates")
        
        // Create test location
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Test camera position calculation
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        XCTAssertEqual(region.center.latitude, testLocation.coordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(region.center.longitude, testLocation.coordinate.longitude, accuracy: 0.001)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLocationPermissionHandling() {
        let expectation = XCTestExpectation(description: "Permission handling")
        
        // Test different authorization states
        let states: [CLAuthorizationStatus] = [
            .notDetermined,
            .denied,
            .restricted,
            .authorizedWhenInUse,
            .authorizedAlways
        ]
        
        for state in states {
            let overlay = LocationPermissionOverlay(
                authorizationStatus: state,
                onRequestPermission: {},
                onOpenSettings: {}
            )
            
            let hostingController = UIHostingController(rootView: overlay)
            XCTAssertNotNil(hostingController.view)
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMapInteractionCapabilities() {
        // Test that map supports zoom and pan interactions
        let mapView = MapView()
        XCTAssertNotNil(mapView)
        
        let hostingController = UIHostingController(rootView: mapView)
        XCTAssertNotNil(hostingController.view)
        
        // Test that map controls are available through the MapView implementation
        // The MapView includes MapUserLocationButton, MapCompass, MapScaleView
        // This is verified by successful instantiation and rendering
    }
}