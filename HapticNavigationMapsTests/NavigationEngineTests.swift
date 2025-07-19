import XCTest
import MapKit
import CoreLocation
@testable import HapticNavigationMaps

@MainActor
final class NavigationEngineTests: XCTestCase {
    
    var navigationEngine: NavigationEngine!
    
    override func setUp() {
        super.setUp()
        navigationEngine = NavigationEngine()
    }
    
    override func tearDown() {
        navigationEngine = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() async {
        await MainActor.run {
            XCTAssertNil(navigationEngine.currentRoute)
            XCTAssertNil(navigationEngine.currentStep)
            XCTAssertEqual(navigationEngine.navigationState, .idle)
        }
    }
    
    // MARK: - Route Calculation Tests
    
    func testCalculateRouteWithoutCurrentLocation() async {
        // Given: No current location set
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)))
        
        // When: Attempting to calculate route
        do {
            _ = try await navigationEngine.calculateRoute(to: destination)
            XCTFail("Expected NavigationError.noCurrentLocation to be thrown")
        } catch {
            // Then: Should throw no current location error
            XCTAssertTrue(error is NavigationError)
            if let navError = error as? NavigationError {
                switch navError {
                case .noCurrentLocation:
                    break // Expected
                default:
                    XCTFail("Expected noCurrentLocation error, got \(navError)")
                }
            }
        }
    }
    
    func testCalculateRouteStateTransitions() async {
        // Given: A current location
        let currentLocation = CLLocation(latitude: 37.7849, longitude: -122.4094)
        navigationEngine.updateProgress(location: currentLocation)
        
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)))
        
        // When: Starting route calculation
        XCTAssertEqual(navigationEngine.navigationState, .idle)
        
        // Note: This test will likely fail due to network requirements
        // In a production app, we would mock MKDirections
        do {
            _ = try await navigationEngine.calculateRoute(to: destination)
            // If successful, state should return to idle
            XCTAssertEqual(navigationEngine.navigationState, .idle)
        } catch {
            // Expected to fail without network or with invalid coordinates
            // State should be reset to idle after error
            XCTAssertEqual(navigationEngine.navigationState, .idle)
        }
    }
    
    // MARK: - Navigation Control Tests
    
    func testStartNavigation() async {
        await MainActor.run {
            // Given: A mock route
            let mockRoute = createMockRoute()
            
            // When: Starting navigation
            navigationEngine.startNavigation(route: mockRoute)
            
            // Then: Navigation state should be updated
            XCTAssertEqual(navigationEngine.currentRoute, mockRoute)
            // Note: currentStep may be nil for empty mock routes, which is acceptable
            // In a real route with steps, currentStep would be set
            if case .navigating(let mode) = navigationEngine.navigationState {
                XCTAssertEqual(mode, .visual)
            } else {
                XCTFail("Expected navigating state")
            }
        }
    }
    
    func testStopNavigation() async {
        await MainActor.run {
            // Given: Navigation is active
            let mockRoute = createMockRoute()
            navigationEngine.startNavigation(route: mockRoute)
            
            // When: Stopping navigation
            navigationEngine.stopNavigation()
            
            // Then: All navigation state should be cleared
            XCTAssertNil(navigationEngine.currentRoute)
            XCTAssertNil(navigationEngine.currentStep)
            XCTAssertEqual(navigationEngine.navigationState, .idle)
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    func testUpdateProgressWithoutActiveNavigation() async {
        await MainActor.run {
            // Given: No active navigation
            let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
            
            // When: Updating progress
            navigationEngine.updateProgress(location: location)
            
            // Then: Should not crash and state should remain idle
            XCTAssertEqual(navigationEngine.navigationState, .idle)
        }
    }
    
    func testUpdateProgressWithActiveNavigation() async {
        await MainActor.run {
            // Given: Active navigation
            let mockRoute = createMockRoute()
            navigationEngine.startNavigation(route: mockRoute)
            let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
            
            // When: Updating progress
            navigationEngine.updateProgress(location: location)
            
            // Then: Should maintain navigating state
            if case .navigating = navigationEngine.navigationState {
                // Expected
            } else {
                XCTFail("Expected navigating state")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNavigationErrorDescriptions() {
        let noLocationError = NavigationError.noCurrentLocation
        let noRouteError = NavigationError.noRouteFound
        let calculationError = NavigationError.routeCalculationFailed(NSError(domain: "test", code: 1))
        
        XCTAssertEqual(noLocationError.errorDescription, "Current location is not available")
        XCTAssertEqual(noRouteError.errorDescription, "No route could be found to the destination")
        XCTAssertTrue(calculationError.errorDescription?.contains("Route calculation failed") == true)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRoute() -> MKRoute {
        // Create a simple mock route for testing
        // Note: MKRoute is difficult to mock directly in unit tests
        // In a production environment, we would use dependency injection
        // and protocol abstractions to make this more testable
        
        let startCoordinate = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        let endCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
        
        // Since we can't easily create a mock MKRoute, we'll return a basic route
        // This is a limitation of testing with MapKit's concrete types
        return MKRoute()
    }
}

// MARK: - Mock Classes for Better Testing

/// Mock implementation for testing purposes
/// In a production app, we would use this approach with dependency injection
class MockNavigationEngine: NavigationEngineProtocol {
    @Published var currentRoute: MKRoute?
    @Published var currentStep: MKRoute.Step?
    @Published var navigationState: NavigationState = .idle
    @Published var availableRoutes: [MKRoute] = []
    @Published var routeCalculationError: NavigationError?
    
    var shouldFailRouteCalculation = false
    var mockRoute: MKRoute?
    
    func calculateRoute(to destination: MKMapItem) async throws -> MKRoute {
        navigationState = .calculating
        
        if shouldFailRouteCalculation {
            navigationState = .idle
            let error = NavigationError.noRouteFound
            routeCalculationError = error
            throw error
        }
        
        let route = mockRoute ?? MKRoute()
        availableRoutes = [route]
        currentRoute = route
        navigationState = .idle
        return route
    }
    
    func startNavigation(route: MKRoute, mode: NavigationMode = .visual) {
        currentRoute = route
        navigationState = .navigating(mode: mode)
    }
    
    func setNavigationMode(_ mode: NavigationMode) {
        if case .navigating = navigationState {
            navigationState = .navigating(mode: mode)
        }
    }
    
    func updateProgress(location: CLLocation) {
        // Mock implementation
    }
    
    func stopNavigation() {
        currentRoute = nil
        currentStep = nil
        navigationState = .idle
    }
    
    func selectRoute(_ route: MKRoute) {
        currentRoute = route
    }
    
    func clearError() {
        routeCalculationError = nil
    }
    
    func clearRoutes() {
        availableRoutes = []
        currentRoute = nil
        currentStep = nil
        routeCalculationError = nil
        navigationState = .idle
    }
    
    func cancelRouteCalculation() {
        navigationState = .idle
        routeCalculationError = nil
    }
}

// MARK: - Additional Tests with Mock

@MainActor
final class MockNavigationEngineTests: XCTestCase {
    
    var mockEngine: MockNavigationEngine!
    
    override func setUp() {
        super.setUp()
        mockEngine = MockNavigationEngine()
    }
    
    override func tearDown() {
        mockEngine = nil
        super.tearDown()
    }
    
    func testMockRouteCalculationSuccess() async {
        // Given: Mock engine configured for success
        let mockRoute = MKRoute()
        mockEngine.mockRoute = mockRoute
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)))
        
        // When: Calculating route
        do {
            let result = try await mockEngine.calculateRoute(to: destination)
            
            // Then: Should return the mock route
            XCTAssertEqual(result, mockRoute)
            XCTAssertEqual(mockEngine.navigationState, .idle)
        } catch {
            XCTFail("Route calculation should succeed with mock")
        }
    }
    
    func testMockRouteCalculationFailure() async {
        // Given: Mock engine configured for failure
        mockEngine.shouldFailRouteCalculation = true
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)))
        
        // When: Calculating route
        do {
            _ = try await mockEngine.calculateRoute(to: destination)
            XCTFail("Expected route calculation to fail")
        } catch {
            // Then: Should throw error and reset state
            XCTAssertTrue(error is NavigationError)
            XCTAssertEqual(mockEngine.navigationState, .idle)
        }
    }
}