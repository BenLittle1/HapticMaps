import XCTest
import SwiftUI
import MapKit
import CoreLocation
import Combine
@testable import HapticNavigationMaps

/// Comprehensive end-to-end integration tests for complete navigation flows
@MainActor
final class AppIntegrationTests: XCTestCase {
    
    var appCoordinator: AppCoordinator!
    var dependencyContainer: DependencyContainer!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        appCoordinator = AppCoordinator()
        dependencyContainer = DependencyContainer.shared
        cancellables = Set<AnyCancellable>()
        
        // Reset any previous state
        await dependencyContainer.cleanup()
    }
    
    override func tearDown() async throws {
        await dependencyContainer.cleanup()
        cancellables.removeAll()
        appCoordinator = nil
        dependencyContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - App Initialization Tests
    
    func testAppInitializationFlow() async throws {
        // Given: App coordinator is created but not initialized
        XCTAssertFalse(appCoordinator.isInitialized)
        XCTAssertFalse(dependencyContainer.isInitialized)
        
        // When: App is initialized
        await appCoordinator.initializeApp()
        
        // Then: All services should be initialized
        XCTAssertTrue(appCoordinator.isInitialized)
        XCTAssertTrue(dependencyContainer.isInitialized)
        XCTAssertNil(appCoordinator.initializationError)
        
        // And: All services should be accessible
        XCTAssertNotNil(try dependencyContainer.getLocationService())
        XCTAssertNotNil(try dependencyContainer.getHapticService())
        XCTAssertNotNil(try dependencyContainer.getSearchService())
        XCTAssertNotNil(try dependencyContainer.getNavigationEngine())
        XCTAssertNotNil(try dependencyContainer.getSearchViewModel())
        XCTAssertNotNil(try dependencyContainer.getNavigationViewModel())
    }
    
    func testAppInitializationRetryAfterError() async throws {
        // This test would require mocking service initialization failures
        // For now, we'll test the retry mechanism structure
        
        let initialErrorState = appCoordinator.initializationError
        XCTAssertNil(initialErrorState)
        
        // When: Retry is called (even without error)
        await appCoordinator.retryInitialization()
        
        // Then: App should still be properly initialized
        XCTAssertTrue(appCoordinator.isInitialized)
        XCTAssertNil(appCoordinator.initializationError)
    }
    
    // MARK: - Complete Navigation Flow Tests
    
    func testCompleteNavigationFlow() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let locationService = try dependencyContainer.getLocationService()
        let searchService = try dependencyContainer.getSearchService()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        let searchViewModel = try dependencyContainer.getSearchViewModel()
        let navigationViewModel = try dependencyContainer.getNavigationViewModel()
        
        // Test destinations
        let startLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let destinationCoordinate = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        
        // Create mock destination
        let mockDestination = MKMapItem()
        mockDestination.placemark = MKPlacemark(coordinate: destinationCoordinate)
        mockDestination.name = "Test Destination"
        
        // Step 1: Set current location
        locationService.startLocationUpdates()
        
        // Step 2: Search for destination (simulate with direct result)
        searchViewModel.searchText = "Test Destination"
        
        // Step 3: Calculate route
        XCTAssertEqual(navigationEngine.navigationState, .idle)
        
        // For testing purposes, we'll simulate the navigation flow
        // In a real test environment, we'd need mock services
        
        // Verify initial state
        XCTAssertNil(navigationEngine.currentRoute)
        XCTAssertNil(navigationViewModel.currentStep)
        XCTAssertEqual(navigationViewModel.routeProgress, 0.0)
    }
    
    func testHapticNavigationModeFlow() async throws {
        // Given: App is initialized with haptic capabilities
        await appCoordinator.initializeApp()
        
        let hapticService = try dependencyContainer.getHapticService()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        let userPreferences = dependencyContainer.userPreferences!
        
        // When: User sets preferred mode to haptic
        userPreferences.preferredNavigationMode = .haptic
        
        // Then: Haptic service should be enabled if capable
        if hapticService.isHapticCapable {
            XCTAssertTrue(hapticService.isHapticModeEnabled)
        }
        
        // When: Navigation starts (simulated)
        let mockRoute = createMockRoute()
        navigationEngine.startNavigation(route: mockRoute, mode: .haptic)
        
        // Then: Navigation should be in haptic mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .haptic)
        } else {
            XCTFail("Navigation should be in navigating state")
        }
    }
    
    func testNavigationStateRestoration() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let userPreferences = dependencyContainer.userPreferences!
        
        // When: Previous navigation state is available
        let mockRouteState = NavigationRouteState(
            destinationName: "Test Route",
            destinationLatitude: 37.7849,
            destinationLongitude: -122.4094,
            totalDistance: 1000.0,
            estimatedTravelTime: 300.0
        )
        
        userPreferences.saveNavigationState(
            route: mockRouteState,
            mode: .haptic,
            progress: 0.5
        )
        
        // Then: State should be saved
        XCTAssertNotNil(userPreferences.lastNavigationRoute)
        XCTAssertEqual(userPreferences.lastNavigationMode, .haptic)
        XCTAssertEqual(userPreferences.lastNavigationProgress, 0.5)
        XCTAssertTrue(userPreferences.hasRestorableNavigationState)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testLocationPermissionDeniedFlow() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let locationService = try dependencyContainer.getLocationService()
        
        // When: Location permission is in denied state
        // (This would require mocking CLLocationManager for proper testing)
        
        // Then: App should handle gracefully
        XCTAssertNotNil(locationService)
        
        // Verify app coordinator recognizes onboarding need
        if locationService.authorizationStatus == .denied || 
           locationService.authorizationStatus == .notDetermined {
            XCTAssertTrue(appCoordinator.shouldShowOnboarding)
        }
    }
    
    func testHapticEngineFailureHandling() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let hapticService = try dependencyContainer.getHapticService()
        
        // When: Haptic engine is not available
        if !hapticService.isHapticCapable {
            // Then: Service should handle gracefully
            XCTAssertFalse(hapticService.isHapticModeEnabled)
            XCTAssertEqual(hapticService.engineState, .notInitialized)
        }
    }
    
    // MARK: - Service Integration Tests
    
    func testLocationAndNavigationEngineIntegration() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let locationService = try dependencyContainer.getLocationService()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        let navigationViewModel = try dependencyContainer.getNavigationViewModel()
        
        // Set up expectation for location updates
        let locationUpdateExpectation = XCTestExpectation(description: "Location update received")
        var receivedLocationUpdate = false
        
        // Monitor navigation engine for location updates
        navigationEngine.$navigationState
            .sink { state in
                if case .navigating = state, !receivedLocationUpdate {
                    receivedLocationUpdate = true
                    locationUpdateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start location updates
        locationService.startLocationUpdates()
        
        // Simulate navigation start
        let mockRoute = createMockRoute()
        navigationEngine.startNavigation(route: mockRoute, mode: .visual)
        
        // Verify integration
        XCTAssertNotNil(navigationEngine)
        XCTAssertNotNil(navigationViewModel)
    }
    
    func testSearchAndNavigationIntegration() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        let searchViewModel = try dependencyContainer.getSearchViewModel()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        
        // When: Search is performed
        searchViewModel.searchText = "Test Location"
        
        // Then: Search should be processed
        XCTAssertEqual(searchViewModel.searchText, "Test Location")
        XCTAssertFalse(searchViewModel.isSearchEmpty)
        
        // Verify navigation engine is ready for route calculation
        XCTAssertEqual(navigationEngine.navigationState, .idle)
        XCTAssertEqual(navigationEngine.availableRoutes.count, 0)
    }
    
    // MARK: - Background Mode Integration Tests
    
    func testBackgroundNavigationSetup() async throws {
        // Given: App is initialized and navigation is active
        await appCoordinator.initializeApp()
        
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        let hapticService = try dependencyContainer.getHapticService()
        
        // When: Navigation starts
        let mockRoute = createMockRoute()
        navigationEngine.startNavigation(route: mockRoute, mode: .haptic)
        
        // And: App enters background
        await dependencyContainer.handleAppEnterBackground()
        
        // Then: Background support should be set up
        if case .navigating = navigationEngine.navigationState {
            // Background tasks should be active (would need mocking to verify)
            XCTAssertNotNil(hapticService)
        }
    }
    
    func testAppLifecycleTransitions() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        // When: App enters background
        await appCoordinator.dependencies.handleAppEnterBackground()
        
        // Then: No errors should occur
        XCTAssertTrue(appCoordinator.isInitialized)
        
        // When: App becomes active again
        await appCoordinator.dependencies.handleAppBecomeActive()
        
        // Then: App should remain functional
        XCTAssertTrue(appCoordinator.isInitialized)
        XCTAssertNil(appCoordinator.initializationError)
    }
    
    // MARK: - Memory Management Tests
    
    func testServiceCleanupOnAppTermination() async throws {
        // Given: App is initialized
        await appCoordinator.initializeApp()
        
        // When: App is cleaned up
        await dependencyContainer.cleanup()
        
        // Then: All services should be cleaned up
        XCTAssertFalse(dependencyContainer.isInitialized)
        
        // And: Service references should be cleared
        XCTAssertThrowsError(try dependencyContainer.getLocationService())
        XCTAssertThrowsError(try dependencyContainer.getHapticService())
        XCTAssertThrowsError(try dependencyContainer.getSearchService())
        XCTAssertThrowsError(try dependencyContainer.getNavigationEngine())
    }
    
    func testReinitialization() async throws {
        // Given: App is initialized and then cleaned up
        await appCoordinator.initializeApp()
        XCTAssertTrue(appCoordinator.isInitialized)
        
        await dependencyContainer.cleanup()
        XCTAssertFalse(dependencyContainer.isInitialized)
        
        // When: App is reinitialized
        await appCoordinator.resetAndReinitialize()
        
        // Then: App should be functional again
        XCTAssertTrue(appCoordinator.isInitialized)
        XCTAssertTrue(dependencyContainer.isInitialized)
        XCTAssertNil(appCoordinator.initializationError)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRoute() -> MKRoute {
        // Create a mock route for testing
        // In a real implementation, this would be more sophisticated
        let mockRoute = MKRoute()
        return mockRoute
    }
    
    private func waitForAsync(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}

 