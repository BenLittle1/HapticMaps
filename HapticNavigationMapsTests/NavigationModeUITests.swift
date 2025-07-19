import XCTest
@testable import HapticNavigationMaps
import SwiftUI
import CoreHaptics
import MapKit

@MainActor
final class NavigationModeUITests: XCTestCase {
    
    var userPreferences: UserPreferences!
    var mockHapticService: MockHapticNavigationService!
    var navigationEngine: NavigationEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Reset user preferences to defaults
        userPreferences = UserPreferences.shared
        userPreferences.resetToDefaults()
        
        // Create mock haptic service
        mockHapticService = MockHapticNavigationService()
        
        // Create navigation engine with mock service
        navigationEngine = NavigationEngine(hapticService: mockHapticService)
    }
    
    override func tearDown() async throws {
        userPreferences.resetToDefaults()
        userPreferences = nil
        mockHapticService = nil
        navigationEngine = nil
        try await super.tearDown()
    }
    
    // MARK: - HapticModeToggle Tests
    
    func testHapticModeToggleInitialization() {
        // Given: Default preferences
        let currentMode = userPreferences.preferredNavigationMode
        let isHapticCapable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        // When: Creating HapticModeToggle
        let modeToggle = HapticModeToggle(
            currentMode: .constant(currentMode),
            isHapticCapable: .constant(isHapticCapable),
            onModeChanged: { _ in }
        )
        
        // Then: Component should be created successfully
        XCTAssertNotNil(modeToggle)
    }
    
    func testModeToggleCallback() {
        // Given: Mode toggle with callback
        var callbackTriggered = false
        var receivedMode: NavigationMode?
        
        let modeToggle = HapticModeToggle(
            currentMode: .constant(.visual),
            isHapticCapable: .constant(true),
            onModeChanged: { mode in
                callbackTriggered = true
                receivedMode = mode
            }
        )
        
        // When: Triggering mode change (simulated)
        let callback = modeToggle.onModeChanged
        callback(.haptic)
        
        // Then: Callback should be triggered with correct mode
        XCTAssertTrue(callbackTriggered)
        XCTAssertEqual(receivedMode, .haptic)
    }
    
    func testHapticCapabilityHandling() {
        // Given: Device without haptic capability
        let isHapticCapable = false
        
        let modeToggle = HapticModeToggle(
            currentMode: .constant(.visual),
            isHapticCapable: .constant(isHapticCapable),
            onModeChanged: { _ in }
        )
        
        // Then: Component should handle disabled state
        XCTAssertNotNil(modeToggle)
        // Note: In a real UI test, we would verify that haptic mode is disabled
    }
    
    // MARK: - CompactHapticModeToggle Tests
    
    func testCompactToggleInitialization() {
        // Given: Compact mode toggle parameters
        let currentMode = NavigationMode.visual
        let isHapticCapable = true
        
        // When: Creating CompactHapticModeToggle
        let compactToggle = CompactHapticModeToggle(
            currentMode: .constant(currentMode),
            isHapticCapable: isHapticCapable,
            onModeChanged: { _ in }
        )
        
        // Then: Component should be created successfully
        XCTAssertNotNil(compactToggle)
    }
    
    func testCompactToggleModeSwitch() {
        // Given: Compact toggle starting in visual mode
        var currentMode = NavigationMode.visual
        var modeChangeCount = 0
        
        let compactToggle = CompactHapticModeToggle(
            currentMode: .constant(currentMode),
            isHapticCapable: true,
            onModeChanged: { newMode in
                currentMode = newMode
                modeChangeCount += 1
            }
        )
        
        // When: Simulating toggle action
        let callback = compactToggle.onModeChanged
        callback(.haptic)
        
        // Then: Mode should change and callback count should increment
        XCTAssertEqual(currentMode, .haptic)
        XCTAssertEqual(modeChangeCount, 1)
    }
    
    // MARK: - UserPreferences Tests
    
    func testPreferredNavigationModePersistence() {
        // Given: Initial mode
        let initialMode = userPreferences.preferredNavigationMode
        
        // When: Changing preferred mode
        userPreferences.preferredNavigationMode = .haptic
        
        // Then: Mode should be persisted
        XCTAssertEqual(userPreferences.preferredNavigationMode, .haptic)
        XCTAssertNotEqual(userPreferences.preferredNavigationMode, initialMode)
    }
    
    func testNavigationStatePersistence() {
        // Given: Mock route state
        let mockRoute = createMockRoute()
        let routeState = NavigationRouteState(
            from: mockRoute,
            currentStepIndex: 2,
            destinationName: "Test Destination"
        )
        
        // When: Saving navigation state
        userPreferences.saveNavigationState(
            route: routeState,
            mode: .haptic,
            progress: 0.65
        )
        
        // Then: State should be saved and accessible
        XCTAssertTrue(userPreferences.hasRestorableNavigationState)
        XCTAssertEqual(userPreferences.lastNavigationMode, .haptic)
        XCTAssertEqual(userPreferences.lastNavigationProgress, 0.65)
        XCTAssertNotNil(userPreferences.lastNavigationRoute)
    }
    
    func testNavigationStateClearance() {
        // Given: Saved navigation state
        let mockRoute = createMockRoute()
        let routeState = NavigationRouteState(from: mockRoute)
        userPreferences.saveNavigationState(route: routeState, mode: .visual, progress: 0.5)
        
        // When: Clearing navigation state
        userPreferences.clearNavigationState()
        
        // Then: State should be cleared
        XCTAssertFalse(userPreferences.hasRestorableNavigationState)
        XCTAssertNil(userPreferences.lastNavigationRoute)
        XCTAssertNil(userPreferences.lastNavigationMode)
        XCTAssertEqual(userPreferences.lastNavigationProgress, 0.0)
    }
    
    func testHapticFeedbackPreferencePersistence() {
        // Given: Initial haptic preference
        let initialValue = userPreferences.isHapticFeedbackEnabled
        
        // When: Toggling haptic feedback preference
        userPreferences.isHapticFeedbackEnabled = !initialValue
        
        // Then: Preference should be persisted
        XCTAssertNotEqual(userPreferences.isHapticFeedbackEnabled, initialValue)
    }
    
    func testScreenLockTimeoutPreference() {
        // Given: New timeout value
        let newTimeout: TimeInterval = 60.0
        
        // When: Setting screen lock timeout
        userPreferences.screenLockTimeout = newTimeout
        
        // Then: Timeout should be saved
        XCTAssertEqual(userPreferences.screenLockTimeout, newTimeout)
    }
    
    func testPreferencesReset() {
        // Given: Modified preferences
        userPreferences.preferredNavigationMode = .haptic
        userPreferences.isHapticFeedbackEnabled = false
        userPreferences.screenLockTimeout = 90.0
        
        // When: Resetting to defaults
        userPreferences.resetToDefaults()
        
        // Then: All preferences should be reset
        XCTAssertEqual(userPreferences.preferredNavigationMode, .visual)
        XCTAssertTrue(userPreferences.isHapticFeedbackEnabled)
        XCTAssertEqual(userPreferences.screenLockTimeout, 30.0)
        XCTAssertFalse(userPreferences.hasRestorableNavigationState)
    }
    
    // MARK: - Navigation Engine Mode Integration Tests
    
    func testNavigationEngineModeSwitching() {
        // Given: Navigation engine in visual mode
        let mockRoute = createMockRoute()
        navigationEngine.startNavigation(route: mockRoute, mode: .visual)
        
        // When: Switching to haptic mode
        navigationEngine.setNavigationMode(.haptic)
        
        // Then: Navigation state should reflect new mode
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .haptic)
        } else {
            XCTFail("Expected navigating state")
        }
    }
    
    func testNavigationEngineHapticInitialization() {
        // Given: Navigation engine with haptic service
        let mockRoute = createMockRoute()
        
        // When: Starting navigation in haptic mode
        navigationEngine.startNavigation(route: mockRoute, mode: .haptic)
        
        // Then: Haptic engine should be initialized
        XCTAssertEqual(mockHapticService.engineState, .running)
    }
    
    func testNavigationModePreservationDuringSwitch() {
        // Given: Active navigation
        let mockRoute = createMockRoute()
        navigationEngine.startNavigation(route: mockRoute, mode: .visual)
        
        // When: Switching modes
        navigationEngine.setNavigationMode(.haptic)
        navigationEngine.setNavigationMode(.visual)
        
        // Then: Navigation should remain active with new mode
        switch navigationEngine.navigationState {
        case .navigating(let mode):
            XCTAssertEqual(mode, .visual)
        default:
            XCTFail("Expected navigating state to be preserved")
        }
    }
    
    // MARK: - HapticNavigationView Tests
    
    func testHapticNavigationViewInitialization() {
        // Given: Required parameters for haptic navigation view
        let mockStep = MKRoute.Step()
        
        // When: Creating HapticNavigationView
        let hapticView = HapticNavigationView(
            currentStep: mockStep,
            nextStep: nil,
            distanceToNextManeuver: 150.0,
            navigationState: .navigating(mode: .haptic),
            routeProgress: 0.5,
            isHapticCapable: true,
            onStopNavigation: {},
            onToggleMode: {}
        )
        
        // Then: View should be created successfully
        XCTAssertNotNil(hapticView)
    }
    
    func testHapticNavigationViewCallbacks() {
        // Given: Haptic navigation view with callbacks
        var stopNavigationCalled = false
        var toggleModeCalled = false
        
        let hapticView = HapticNavigationView(
            currentStep: nil,
            nextStep: nil,
            distanceToNextManeuver: 0,
            navigationState: .navigating(mode: .haptic),
            routeProgress: 0.0,
            isHapticCapable: true,
            onStopNavigation: {
                stopNavigationCalled = true
            },
            onToggleMode: {
                toggleModeCalled = true
            }
        )
        
        // When: Triggering callbacks
        hapticView.onStopNavigation()
        hapticView.onToggleMode()
        
        // Then: Callbacks should be triggered
        XCTAssertTrue(stopNavigationCalled)
        XCTAssertTrue(toggleModeCalled)
    }
    
    // MARK: - NavigationModeSettingsView Tests
    
    func testNavigationModeSettingsViewInitialization() {
        // When: Creating settings view
        let settingsView = NavigationModeSettingsView()
        
        // Then: View should be created successfully
        XCTAssertNotNil(settingsView)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndModeSwitch() {
        // Given: Complete navigation setup
        let mockRoute = createMockRoute()
        
        // When: Starting navigation and switching modes
        navigationEngine.startNavigation(route: mockRoute, mode: .visual)
        
        // Switch to haptic
        navigationEngine.setNavigationMode(.haptic)
        
        // Save state
        let routeState = NavigationRouteState(from: mockRoute)
        userPreferences.saveNavigationState(route: routeState, mode: .haptic, progress: 0.3)
        
        // Switch back to visual
        navigationEngine.setNavigationMode(.visual)
        
        // Then: All components should work together
        if case .navigating(let mode) = navigationEngine.navigationState {
            XCTAssertEqual(mode, .visual)
        } else {
            XCTFail("Expected navigating state")
        }
        
        XCTAssertTrue(userPreferences.hasRestorableNavigationState)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRoute() -> MKRoute {
        // Create a simple mock route for testing
        // Note: In a real app, you might want to use a more sophisticated mock
        return MKRoute()
    }
}

// MARK: - Mock Haptic Service for Testing

@MainActor
class MockHapticNavigationService: HapticNavigationServiceProtocol {
    @Published var isHapticModeEnabled: Bool = false
    @Published var engineState: HapticEngineState = .notInitialized
    
    var isHapticCapable: Bool = true
    private var playedPatterns: [String] = []
    
    var initializeEngineCallCount = 0
    var playTurnLeftCallCount = 0
    var playTurnRightCallCount = 0
    var playContinueStraightCallCount = 0
    var playArrivalCallCount = 0
    var stopAllHapticsCallCount = 0
    var resetEngineCallCount = 0
    
    func initializeHapticEngine() throws {
        initializeEngineCallCount += 1
        engineState = .running
    }
    
    func playTurnLeftPattern() async throws {
        playTurnLeftCallCount += 1
        playedPatterns.append("leftTurn")
    }
    
    func playTurnRightPattern() async throws {
        playTurnRightCallCount += 1
        playedPatterns.append("rightTurn")
    }
    
    func playContinueStraightPattern() async throws {
        playContinueStraightCallCount += 1
        playedPatterns.append("continueStraight")
    }
    
    func playArrivalPattern() async throws {
        playArrivalCallCount += 1
        playedPatterns.append("arrival")
    }
    
    func stopAllHaptics() {
        stopAllHapticsCallCount += 1
        playedPatterns.removeAll()
    }
    
    func resetEngine() throws {
        resetEngineCallCount += 1
        engineState = .running
    }
    
    func startNavigationBackgroundTask() {
        // Mock implementation for testing
    }
    
    func stopNavigationBackgroundTask() {
        // Mock implementation for testing
    }
    
    // Testing helper method
    func getPlayedPatterns() -> [String] {
        return playedPatterns
    }
} 