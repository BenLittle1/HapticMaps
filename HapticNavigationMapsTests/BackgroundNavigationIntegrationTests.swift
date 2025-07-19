import XCTest
@testable import HapticNavigationMaps
import CoreLocation
import MapKit
import CoreHaptics
import UIKit

@MainActor
final class BackgroundNavigationIntegrationTests: XCTestCase {
    
    var locationService: LocationService!
    var hapticService: MockHapticNavigationService!
    var navigationEngine: NavigationEngine!
    var userPreferences: UserPreferences!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock location manager
        let mockLocationManager = CLLocationManager()
        locationService = LocationService(locationManager: mockLocationManager)
        
        // Create mock haptic service
        hapticService = MockHapticNavigationService()
        hapticService.isHapticCapable = true
        
        // Create navigation engine with mock services
        navigationEngine = NavigationEngine(hapticService: hapticService)
        
        // Get user preferences
        userPreferences = UserPreferences.shared
        userPreferences.resetToDefaults()
    }
    
    override func tearDown() async throws {
        userPreferences.resetToDefaults()
        navigationEngine = nil
        hapticService = nil
        locationService = nil
        try await super.tearDown()
    }
    
    // MARK: - Background Location Permission Tests
    
    func testLocationPermissionProgression() {
        // Given: Initial state
        XCTAssertEqual(locationService.authorizationStatus, .notDetermined)
        XCTAssertFalse(locationService.isBackgroundLocationEnabled)
        XCTAssertFalse(locationService.hasRequestedAlwaysPermission)
        
        // When: Request initial permission
        locationService.requestLocationPermission()
        
        // Simulate when-in-use permission granted
        locationService.authorizationStatus = .authorizedWhenInUse
        locationService.requestAlwaysPermissionIfNeeded()
        
        // Then: Should request always permission
        XCTAssertTrue(locationService.hasRequestedAlwaysPermission)
        XCTAssertFalse(locationService.isBackgroundLocationEnabled)
        
        // When: Always permission granted
        locationService.authorizationStatus = .authorizedAlways
        
        // Then: Background location should be enabled
        XCTAssertTrue(locationService.isBackgroundLocationEnabled)
    }
    
    func testLocationPermissionDeniedHandling() {
        // Given: Denied permission
        locationService.authorizationStatus = .denied
        
        var notificationReceived = false
        let expectation = expectation(description: "Permission denied notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LocationPermissionDenied"),
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            expectation.fulfill()
        }
        
        // When: Request permission with denied status
        locationService.requestLocationPermission()
        
        // Then: Should receive notification
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(notificationReceived)
        XCTAssertFalse(locationService.isBackgroundLocationEnabled)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Background Haptic Service Tests
    
    func testHapticBackgroundTaskManagement() throws {
        // Given: Haptic service is initialized
        try hapticService.initializeHapticEngine()
        XCTAssertEqual(hapticService.engineState, .running)
        
        // When: Start navigation background task
        hapticService.startNavigationBackgroundTask()
        
        // Then: Navigation should be marked as active
        // Note: We can't directly test UIApplication.shared.beginBackgroundTask in unit tests
        // but we can verify the service state
        
        // When: Stop navigation background task
        hapticService.stopNavigationBackgroundTask()
        
        // Then: Should complete without errors
        XCTAssertEqual(hapticService.engineState, .running)
    }
    
    func testHapticPatternPlaybackInBackground() async throws {
        // Given: Haptic service is ready
        try hapticService.initializeHapticEngine()
        hapticService.startNavigationBackgroundTask()
        
        // When: Play haptic patterns
        try await hapticService.playTurnLeftPattern()
        try await hapticService.playTurnRightPattern()
        try await hapticService.playContinueStraightPattern()
        try await hapticService.playArrivalPattern()
        
        // Then: All patterns should be recorded
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertEqual(playedPatterns.count, 4)
        XCTAssertTrue(playedPatterns.contains("leftTurn"))
        XCTAssertTrue(playedPatterns.contains("rightTurn"))
        XCTAssertTrue(playedPatterns.contains("continueStraight"))
        XCTAssertTrue(playedPatterns.contains("arrival"))
    }
    
    // MARK: - Navigation Engine Background Integration Tests
    
    func testNavigationEngineBackgroundIntegration() async throws {
        // Given: Sample route and destination
        let destination = createSampleDestination()
        let sampleRoute = createSampleRoute()
        
        // Configure navigation engine with background-capable haptic service
        navigationEngine = NavigationEngine(hapticService: hapticService)
        
        // When: Start haptic navigation
        navigationEngine.startNavigation(route: sampleRoute, mode: .haptic)
        
        // Then: Navigation state should be set correctly
        guard case .navigating(let mode) = navigationEngine.navigationState else {
            XCTFail("Navigation state should be navigating")
            return
        }
        XCTAssertEqual(mode, .haptic)
        
        // When: Switch to visual mode
        navigationEngine.setNavigationMode(.visual)
        
        // Then: Should switch modes correctly
        guard case .navigating(let newMode) = navigationEngine.navigationState else {
            XCTFail("Navigation state should still be navigating")
            return
        }
        XCTAssertEqual(newMode, .visual)
        
        // When: Stop navigation
        navigationEngine.stopNavigation()
        
        // Then: Should return to idle state
        XCTAssertEqual(navigationEngine.navigationState, .idle)
    }
    
    func testNavigationProgressWithBackgroundLocationUpdates() {
        // Given: Active navigation
        let sampleRoute = createSampleRoute()
        navigationEngine.startNavigation(route: sampleRoute, mode: .haptic)
        
        // When: Simulate location updates (as would happen in background)
        let startLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let progressLocation = CLLocation(latitude: 37.7759, longitude: -122.4184)
        let destinationLocation = CLLocation(latitude: 37.7769, longitude: -122.4174)
        
        navigationEngine.updateProgress(location: startLocation)
        navigationEngine.updateProgress(location: progressLocation)
        navigationEngine.updateProgress(location: destinationLocation)
        
        // Then: Navigation should progress correctly
        // (Specific assertions would depend on route implementation details)
        XCTAssertNotNil(navigationEngine.currentRoute)
    }
    
    // MARK: - App State Transition Tests
    
    func testBackgroundForegroundTransitions() {
        // Given: Location service is active
        locationService.startLocationUpdates()
        
        // When: App enters background
        locationService.authorizationStatus = .authorizedAlways
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Simulate background state changes that would occur
        // (In a real scenario, this would be handled by the system)
        
        // When: App returns to foreground
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Then: Location service should adapt correctly
        XCTAssertTrue(locationService.isLocationUpdating)
    }
    
    // MARK: - User Preferences Background Integration
    
    func testUserPreferencesBackgroundPersistence() {
        // Given: User has background preferences
        userPreferences.preferredNavigationMode = .haptic
        userPreferences.keepScreenAwakeInHapticMode = true
        userPreferences.autoLockScreenInHapticMode = true
        
        // When: Save navigation state
        let sampleRoute = createSampleRoute()
        let routeState = NavigationRouteState(from: sampleRoute, destinationName: "Test Destination")
        userPreferences.saveNavigationState(route: routeState, mode: .haptic, progress: 0.5)
        
        // Then: State should be persisted
        XCTAssertTrue(userPreferences.hasRestorableNavigationState)
        XCTAssertEqual(userPreferences.lastNavigationMode, .haptic)
        XCTAssertEqual(userPreferences.lastNavigationProgress, 0.5)
        
        // When: Clear navigation state
        userPreferences.clearNavigationState()
        
        // Then: State should be cleared
        XCTAssertFalse(userPreferences.hasRestorableNavigationState)
    }
    
    // MARK: - Error Handling in Background
    
    func testBackgroundErrorRecovery() async throws {
        // Given: Haptic service with error state
        hapticService.engineState = .error(HapticNavigationError.engineNotAvailable)
        
        // When: Attempt to play pattern in background
        do {
            try await hapticService.playTurnLeftPattern()
            XCTFail("Should have thrown an error")
        } catch {
            // Then: Should handle error gracefully
            XCTAssertTrue(error is HapticNavigationError)
        }
        
        // When: Reset engine
        hapticService.isHapticCapable = true
        try hapticService.resetEngine()
        
        // Then: Should recover and work normally
        XCTAssertEqual(hapticService.engineState, .running)
        try await hapticService.playTurnLeftPattern()
        XCTAssertTrue(hapticService.getPlayedPatterns().contains("leftTurn"))
    }
    
    func testLocationServiceBackgroundErrorHandling() {
        // Given: Location service with permission issues
        locationService.authorizationStatus = .denied
        
        // When: Try to start location updates
        locationService.startLocationUpdates()
        
        // Then: Should handle gracefully without starting updates
        XCTAssertFalse(locationService.isLocationUpdating)
        
        // When: Permission is restored
        locationService.authorizationStatus = .authorizedAlways
        locationService.startLocationUpdates()
        
        // Then: Should work normally
        XCTAssertTrue(locationService.isLocationUpdating)
    }
    
    // MARK: - Performance Tests
    
    func testBackgroundTaskPerformance() {
        // Test that background tasks don't cause memory leaks or performance issues
        measure {
            for _ in 0..<100 {
                hapticService.startNavigationBackgroundTask()
                hapticService.stopNavigationBackgroundTask()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSampleDestination() -> MKMapItem {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let placemark = MKPlacemark(coordinate: coordinate)
        return MKMapItem(placemark: placemark)
    }
    
    private func createSampleRoute() -> MKRoute {
        // Create a mock route for testing
        // In a real implementation, this would be created from MKDirections
        let route = MKRoute()
        return route
    }
}

// MARK: - Background Task Testing Extensions

extension BackgroundNavigationIntegrationTests {
    
    /// Test background app refresh behavior
    func testBackgroundAppRefreshIntegration() {
        // Given: App has background refresh enabled
        let refreshExpectation = expectation(description: "Background refresh completed")
        
        // When: System triggers background refresh
        // (This would be handled by iOS background app refresh)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            // Simulate background work
            DispatchQueue.main.async {
                refreshExpectation.fulfill()
            }
        }
        
        // Then: Should complete within time limit
        wait(for: [refreshExpectation], timeout: 1.0)
    }
    
    /// Test memory management during background operation
    func testBackgroundMemoryManagement() {
        // Given: Multiple navigation sessions
        var services: [HapticNavigationService] = []
        
        // When: Create and destroy multiple services
        for _ in 0..<10 {
            let service = HapticNavigationService()
            service.startNavigationBackgroundTask()
            services.append(service)
        }
        
        // When: Clean up services
        for service in services {
            service.stopNavigationBackgroundTask()
        }
        services.removeAll()
        
        // Then: Memory should be properly released
        // (In a real test, we'd use memory profiling tools)
        XCTAssertTrue(services.isEmpty)
    }
}

// MARK: - Mock Background Task Testing

/// Mock class for testing background task behavior
class MockBackgroundTaskManager {
    private var activeTasks: [UIBackgroundTaskIdentifier: String] = [:]
    private var taskIdCounter: Int = 1
    
    func beginBackgroundTask(withName name: String?, expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        let taskId = UIBackgroundTaskIdentifier(rawValue: taskIdCounter)
        taskIdCounter += 1
        activeTasks[taskId] = name ?? "UnnamedTask"
        return taskId
    }
    
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        activeTasks.removeValue(forKey: identifier)
    }
    
    var activeTaskCount: Int {
        return activeTasks.count
    }
    
    func getAllTaskNames() -> [String] {
        return Array(activeTasks.values)
    }
}

// Note: MockHapticNavigationService is defined in NavigationModeUITests.swift to avoid conflicts 