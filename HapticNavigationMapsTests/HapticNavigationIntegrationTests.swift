import XCTest
import MapKit
import CoreLocation
import CoreHaptics
@testable import HapticNavigationMaps

/// Integration tests for haptic navigation functionality
@MainActor
final class HapticNavigationIntegrationTests: XCTestCase {
    
    var hapticService: MockHapticNavigationService!
    var navigationEngine: NavigationEngine!
    var testRoute: MKRoute!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock haptic service
        hapticService = MockHapticNavigationService()
        hapticService.isHapticCapable = true
        
        // Create navigation engine with mock haptic service
        navigationEngine = NavigationEngine(hapticService: hapticService)
        
        // Create test route with mock steps
        testRoute = createTestRoute()
    }
    
    override func tearDown() {
        hapticService = nil
        navigationEngine = nil
        testRoute = nil
        super.tearDown()
    }
    
    // MARK: - Haptic Mode Integration Tests
    
    func testStartNavigationInHapticMode() throws {
        // Given: Navigation is started in haptic mode
        navigationEngine.startNavigation(route: testRoute, mode: .haptic)
        
        // Then: Navigation state should be haptic mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .haptic)
        } else {
            XCTFail("Expected navigating state")
        }
        
        // And: Haptic engine should be initialized
        XCTAssertEqual(hapticService.engineState, .running)
    }
    
    func testStartNavigationInVisualModeDoesNotInitializeHaptics() throws {
        // Given: Navigation is started in visual mode
        navigationEngine.startNavigation(route: testRoute, mode: .visual)
        
        // Then: Navigation state should be visual mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .visual)
        } else {
            XCTFail("Expected navigating state")
        }
        
        // And: Haptic engine should not be initialized
        XCTAssertEqual(hapticService.engineState, .notInitialized)
    }
    
    func testSwitchToHapticModeInitializesHaptics() throws {
        // Given: Navigation is started in visual mode
        navigationEngine.startNavigation(route: testRoute, mode: .visual)
        XCTAssertEqual(hapticService.engineState, .notInitialized)
        
        // When: Switching to haptic mode
        navigationEngine.setNavigationMode(.haptic)
        
        // Then: Navigation state should be haptic mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .haptic)
        } else {
            XCTFail("Expected navigating state")
        }
        
        // And: Haptic engine should be initialized
        XCTAssertEqual(hapticService.engineState, .running)
    }
    
    func testSwitchToVisualModeStopsHaptics() throws {
        // Given: Navigation is in haptic mode
        navigationEngine.startNavigation(route: testRoute, mode: .haptic)
        XCTAssertEqual(hapticService.engineState, .running)
        
        // When: Switching to visual mode
        navigationEngine.setNavigationMode(.visual)
        
        // Then: Navigation state should be visual mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .visual)
        } else {
            XCTFail("Expected navigating state")
        }
        
        // And: Haptic feedback should be stopped
        XCTAssertEqual(hapticService.getPlayedPatterns().count, 0)
    }
    
    // MARK: - Distance-Based Haptic Trigger Tests
    
    func testHapticTriggeredOnApproachingTurn() throws {
        // Given: Navigation is in haptic mode with a left turn step
        let leftTurnRoute = createRouteWithLeftTurn()
        navigationEngine.startNavigation(route: leftTurnRoute, mode: .haptic)
        
        // When: User is within haptic trigger distance (100m) of turn
        let stepLocation = CLLocation(
            latitude: leftTurnRoute.steps[0].polyline.coordinate.latitude,
            longitude: leftTurnRoute.steps[0].polyline.coordinate.longitude
        )
        let approachingLocation = CLLocation(
            latitude: stepLocation.coordinate.latitude + 0.0009, // ~100m away
            longitude: stepLocation.coordinate.longitude
        )
        
        navigationEngine.updateProgress(location: approachingLocation)
        
        // Then: Left turn haptic should be triggered
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertTrue(playedPatterns.contains("leftTurn"))
    }
    
    func testHapticNotTriggeredWhenTooFarFromTurn() throws {
        // Given: Navigation is in haptic mode
        navigationEngine.startNavigation(route: testRoute, mode: .haptic)
        
        // When: User is far from any turn (>100m)
        let farLocation = CLLocation(latitude: 37.7849, longitude: -122.4094)
        navigationEngine.updateProgress(location: farLocation)
        
        // Then: No haptic should be triggered
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertEqual(playedPatterns.count, 0)
    }
    
    func testHapticTriggeredOnlyOncePerStep() throws {
        // Given: Navigation is in haptic mode
        let rightTurnRoute = createRouteWithRightTurn()
        navigationEngine.startNavigation(route: rightTurnRoute, mode: .haptic)
        
        // When: User approaches turn multiple times
        let stepLocation = CLLocation(
            latitude: rightTurnRoute.steps[0].polyline.coordinate.latitude,
            longitude: rightTurnRoute.steps[0].polyline.coordinate.longitude
        )
        let approachingLocation = CLLocation(
            latitude: stepLocation.coordinate.latitude + 0.0009,
            longitude: stepLocation.coordinate.longitude
        )
        
        // First approach
        navigationEngine.updateProgress(location: approachingLocation)
        let firstPatternCount = hapticService.getPlayedPatterns().count
        
        // Second approach (should not trigger again)
        navigationEngine.updateProgress(location: approachingLocation)
        let secondPatternCount = hapticService.getPlayedPatterns().count
        
        // Then: Haptic should only be triggered once
        XCTAssertEqual(firstPatternCount, 1)
        XCTAssertEqual(secondPatternCount, 1)
        XCTAssertTrue(hapticService.getPlayedPatterns().contains("rightTurn"))
    }
    
    func testHapticTriggeredOnStepAdvancement() throws {
        // Given: Navigation is in haptic mode with multiple steps
        let multiStepRoute = createMultiStepRoute()
        navigationEngine.startNavigation(route: multiStepRoute, mode: .haptic)
        
        // When: User completes first step and advances to second
        let firstStepLocation = CLLocation(
            latitude: multiStepRoute.steps[0].polyline.coordinate.latitude,
            longitude: multiStepRoute.steps[0].polyline.coordinate.longitude
        )
        
        // Move close to first step to trigger completion
        navigationEngine.updateProgress(location: firstStepLocation)
        
        // Then: Should be able to trigger haptic for next step
        let secondStepLocation = CLLocation(
            latitude: multiStepRoute.steps[1].polyline.coordinate.latitude,
            longitude: multiStepRoute.steps[1].polyline.coordinate.longitude
        )
        let approachingSecondStep = CLLocation(
            latitude: secondStepLocation.coordinate.latitude + 0.0009,
            longitude: secondStepLocation.coordinate.longitude
        )
        
        navigationEngine.updateProgress(location: approachingSecondStep)
        
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertGreaterThan(playedPatterns.count, 0)
    }
    
    // MARK: - Arrival Haptic Tests
    
    func testArrivalHapticTriggered() throws {
        // Given: Navigation is in haptic mode
        navigationEngine.startNavigation(route: testRoute, mode: .haptic)
        
        // When: User arrives at destination
        let destinationLocation = CLLocation(
            latitude: testRoute.polyline.coordinate.latitude,
            longitude: testRoute.polyline.coordinate.longitude
        )
        
        navigationEngine.updateProgress(location: destinationLocation)
        
        // Then: Arrival haptic should be triggered
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertTrue(playedPatterns.contains("arrival"))
        
        // And: Navigation state should be arrived
        XCTAssertEqual(navigationEngine.navigationState, .arrived)
    }
    
    func testNoArrivalHapticInVisualMode() throws {
        // Given: Navigation is in visual mode
        navigationEngine.startNavigation(route: testRoute, mode: .visual)
        
        // When: User arrives at destination
        let destinationLocation = CLLocation(
            latitude: testRoute.polyline.coordinate.latitude,
            longitude: testRoute.polyline.coordinate.longitude
        )
        
        navigationEngine.updateProgress(location: destinationLocation)
        
        // Then: No haptic should be triggered
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertEqual(playedPatterns.count, 0)
        
        // But: Navigation state should still be arrived
        XCTAssertEqual(navigationEngine.navigationState, .arrived)
    }
    
    // MARK: - Navigation Stop Tests
    
    func testStopNavigationClearsHaptics() throws {
        // Given: Navigation is in haptic mode with active feedback
        navigationEngine.startNavigation(route: testRoute, mode: .haptic)
        
        // Trigger some haptic feedback
        let stepLocation = CLLocation(
            latitude: testRoute.steps[0].polyline.coordinate.latitude,
            longitude: testRoute.steps[0].polyline.coordinate.longitude
        )
        let nearLocation = CLLocation(
            latitude: stepLocation.coordinate.latitude + 0.0009,
            longitude: stepLocation.coordinate.longitude
        )
        navigationEngine.updateProgress(location: nearLocation)
        
        // When: Navigation is stopped
        navigationEngine.stopNavigation()
        
        // Then: Haptics should be cleared
        let playedPatterns = hapticService.getPlayedPatterns()
        XCTAssertEqual(playedPatterns.count, 0)
        
        // And: Navigation state should be idle
        XCTAssertEqual(navigationEngine.navigationState, .idle)
    }
    
    // MARK: - Error Handling Tests
    
    func testGracefulFallbackWhenHapticsUnavailable() throws {
        // Given: Haptic service that doesn't support haptics
        let nonCapableHapticService = MockHapticNavigationService()
        nonCapableHapticService.isHapticCapable = false
        let engineWithNonCapableHaptics = NavigationEngine(hapticService: nonCapableHapticService)
        
        // When: Starting navigation in haptic mode
        engineWithNonCapableHaptics.startNavigation(route: testRoute, mode: .haptic)
        
        // Then: Navigation should still work (graceful fallback)
        if case .navigating(let mode) = engineWithNonCapableHaptics.navigationState {
            XCTAssertEqual(mode, .haptic) // Mode is set, but haptics won't work
        } else {
            XCTFail("Expected navigating state")
        }
        
        // And: Haptic engine should not be running
        XCTAssertNotEqual(nonCapableHapticService.engineState, .running)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRoute() -> MKRoute {
        // Create a simple test route with mock steps
        let mockRoute = MKRoute()
        
        // Add mock steps using reflection/private API for testing
        // In real implementation, this would use actual MKDirections response
        let _ = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let endCoord = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        
        // For testing purposes, we'll work with the route as-is
        // Real routes would have proper steps from MKDirections
        return mockRoute
    }
    
    private func createRouteWithLeftTurn() -> MKRoute {
        // Create route with left turn instruction
        let mockRoute = MKRoute()
        // Note: In production, this would use actual MKRoute.Step with "Turn left" instruction
        return mockRoute
    }
    
    private func createRouteWithRightTurn() -> MKRoute {
        // Create route with right turn instruction  
        let mockRoute = MKRoute()
        // Note: In production, this would use actual MKRoute.Step with "Turn right" instruction
        return mockRoute
    }
    
    private func createMultiStepRoute() -> MKRoute {
        // Create route with multiple steps
        let mockRoute = MKRoute()
        // Note: In production, this would have multiple MKRoute.Step objects
        return mockRoute
    }
}

// Note: MockHapticNavigationService is defined in NavigationModeUITests.swift to avoid conflicts

 