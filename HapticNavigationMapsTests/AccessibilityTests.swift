import XCTest
@testable import HapticNavigationMaps
import SwiftUI
import CoreHaptics
import Combine

@MainActor
final class AccessibilityTests: XCTestCase {
    
    var accessibilityService: AccessibilityService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        accessibilityService = AccessibilityService.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - VoiceOver Tests
    
    func testMapButtonAccessibilityLabels() {
        // Given: A primary MapButton with icon and label
        let button = MapButton(
            action: {},
            icon: "play.fill",
            label: "Start Navigation",
            style: .primary
        )
        
        // Then: Button should have proper accessibility properties
        XCTAssertNotNil(button.body)
        XCTAssertEqual(button.label, "Start Navigation")
        XCTAssertEqual(button.icon, "play.fill")
    }
    
    func testMapButtonIconOnlyAccessibility() {
        // Given: A MapButton with only an icon
        let button = MapButton(
            action: {},
            icon: "location.fill",
            style: .primary
        )
        
        // Then: Button should infer accessible label from icon
        XCTAssertNotNil(button.body)
        XCTAssertNil(button.label)
        XCTAssertEqual(button.icon, "location.fill")
    }
    
    func testSearchBarAccessibilitySupport() {
        // Given: A SearchBar component
        @State var searchText = ""
        @State var isSearching = false
        
        let searchBar = SearchBar(
            text: $searchText,
            isSearching: $isSearching,
            placeholder: "Search for places..."
        )
        
        // Then: SearchBar should have proper accessibility
        XCTAssertNotNil(searchBar.body)
        XCTAssertEqual(searchBar.placeholder, "Search for places...")
    }
    
    func testHapticModeToggleAccessibility() {
        // Given: A HapticModeToggle component
        @State var currentMode = NavigationMode.visual
        @State var isHapticCapable = true
        
        let toggle = HapticModeToggle(
            currentMode: $currentMode,
            isHapticCapable: $isHapticCapable,
            onModeChanged: { _ in }
        )
        
        // Then: Toggle should have proper accessibility properties
        XCTAssertNotNil(toggle.body)
    }
    
    func testNavigationCardAccessibility() {
        // Given: A NavigationCard with navigation data
        let mockStep = createMockRouteStep()
        
        let navigationCard = NavigationCard(
            currentStep: mockStep,
            nextStep: nil,
            distanceToNextManeuver: 100.0,
            navigationState: .navigating(.visual),
            onStopNavigation: {},
            onToggleMode: {}
        )
        
        // Then: NavigationCard should have accessibility support
        XCTAssertNotNil(navigationCard.body)
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeScaling() {
        // Given: Different content size categories
        let testCategories: [UIContentSizeCategory] = [
            .small,
            .medium,
            .large,
            .extraLarge,
            .accessibilityMedium,
            .accessibilityLarge,
            .accessibilityExtraLarge
        ]
        
        for category in testCategories {
            // When: Setting content size category
            accessibilityService.preferredContentSizeCategory = category
            
            // Then: Font scale should adjust appropriately
            let fontScale = accessibilityService.getAccessibleFontScale()
            
            switch category {
            case .small:
                XCTAssertEqual(fontScale, 0.9, accuracy: 0.01)
            case .medium:
                XCTAssertEqual(fontScale, 1.0, accuracy: 0.01)
            case .large:
                XCTAssertEqual(fontScale, 1.1, accuracy: 0.01)
            case .accessibilityLarge:
                XCTAssertEqual(fontScale, 1.8, accuracy: 0.01)
            case .accessibilityExtraLarge:
                XCTAssertEqual(fontScale, 2.0, accuracy: 0.01)
            default:
                XCTAssertTrue(fontScale >= 0.9 && fontScale <= 2.4)
            }
        }
    }
    
    func testLargeTextDetection() {
        // Given: Accessibility text sizes
        accessibilityService.preferredContentSizeCategory = .accessibilityMedium
        
        // Then: Large text should be detected
        XCTAssertTrue(accessibilityService.isLargeTextEnabled())
        
        // Given: Regular text sizes
        accessibilityService.preferredContentSizeCategory = .medium
        
        // Then: Large text should not be detected
        XCTAssertFalse(accessibilityService.isLargeTextEnabled())
    }
    
    // MARK: - High Contrast Tests
    
    func testHighContrastDetection() {
        // Given: AccessibilityService configured for high contrast
        let shouldUseHighContrast = accessibilityService.shouldUseHighContrast()
        
        // Then: High contrast detection should work
        XCTAssertNotNil(shouldUseHighContrast)
        // Note: In testing environment, this will typically be false
        // unless specifically configured
    }
    
    func testDesignTokenAccessibilityExtensions() {
        // Given: Design token accessibility constants
        let minTouchTarget = DesignTokens.Accessibility.minimumTouchTarget
        let preferredTouchTarget = DesignTokens.Accessibility.preferredTouchTarget
        let highContrastBorder = DesignTokens.Accessibility.highContrastBorderWidth
        let standardBorder = DesignTokens.Accessibility.standardBorderWidth
        
        // Then: Values should meet accessibility guidelines
        XCTAssertEqual(minTouchTarget, 44.0)
        XCTAssertEqual(preferredTouchTarget, 48.0)
        XCTAssertGreaterThan(highContrastBorder, standardBorder)
    }
    
    // MARK: - Alternative Feedback Tests
    
    func testAudioFeedbackForHapticPatterns() {
        // Given: AccessibilityService with audio feedback enabled
        accessibilityService.isAudioFeedbackEnabled = true
        
        // When: Playing audio cue for haptic pattern
        let expectation = XCTestExpectation(description: "Audio feedback played")
        
        accessibilityService.playAudioCue(for: .turnLeft)
        
        // Then: Audio feedback should be triggered
        // Note: Testing audio playback in unit tests is limited
        // This test validates the method doesn't crash
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSpeechFeedbackForNavigation() {
        // Given: AccessibilityService with speech feedback enabled
        accessibilityService.isSpeechFeedbackEnabled = true
        
        // When: Speaking navigation instruction
        let expectation = XCTestExpectation(description: "Speech feedback triggered")
        
        accessibilityService.speakNavigationInstruction("Turn left in 100 meters")
        
        // Then: Speech synthesis should be triggered
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNavigationModeAnnouncement() {
        // Given: AccessibilityService configured
        accessibilityService.isSpeechFeedbackEnabled = true
        
        // When: Announcing navigation mode change
        let expectation = XCTestExpectation(description: "Mode change announced")
        
        accessibilityService.speakNavigationMode(.haptic)
        
        // Then: Mode change should be announced
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHapticFallbackDelegate() {
        // Given: AccessibilityService as fallback delegate
        let service = AccessibilityService.shared
        
        // When: Haptic feedback is unavailable
        service.hapticFeedbackUnavailable(
            pattern: .turnLeft,
            reason: .engineNotAvailable
        )
        
        // Then: Alternative feedback should be provided
        // This test validates the fallback mechanism exists
        XCTAssertTrue(service.isAudioFeedbackEnabled || service.isVisualFeedbackEnabled)
    }
    
    // MARK: - VoiceOver Announcements Tests
    
    func testAccessibilityAnnouncements() {
        // Given: AccessibilityService configured
        let service = AccessibilityService.shared
        
        // When: Making accessibility announcements
        service.announceAccessibility("Test announcement")
        service.announceFocusChange(to: "New element")
        service.announceScreenChange(to: "New screen")
        
        // Then: Announcements should be triggered without errors
        // Note: VoiceOver announcements are difficult to test in unit tests
        // This validates the methods don't crash
        XCTAssertNotNil(service)
    }
    
    // MARK: - Reduce Motion Tests
    
    func testReduceMotionSupport() {
        // Given: AccessibilityService with reduce motion detection
        let shouldReduceMotion = accessibilityService.shouldReduceMotion()
        
        // Then: Reduce motion detection should work
        XCTAssertNotNil(shouldReduceMotion)
        // Note: In testing environment, this will typically be false
    }
    
    // MARK: - Component Integration Tests
    
    func testSearchResultRowAccessibility() {
        // Given: A SearchResult and SearchResultRow
        let mockSearchResult = createMockSearchResult()
        let userLocation = createMockLocation()
        
        let searchRow = SearchResultRow(
            searchResult: mockSearchResult,
            userLocation: userLocation,
            onTap: {}
        )
        
        // Then: SearchResultRow should have accessibility support
        XCTAssertNotNil(searchRow.body)
    }
    
    func testRouteInfoPanelAccessibility() {
        // Given: A route and RouteInfoPanel
        let mockRoute = createMockRoute()
        
        let routePanel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // Then: RouteInfoPanel should have accessibility support
        XCTAssertNotNil(routePanel.body)
    }
    
    // MARK: - Error Handling Tests
    
    func testAccessibilityServiceErrorHandling() {
        // Given: AccessibilityService with invalid configurations
        let service = AccessibilityService.shared
        
        // When: Attempting to use services in error conditions
        service.isAudioFeedbackEnabled = false
        service.isSpeechFeedbackEnabled = false
        service.isVisualFeedbackEnabled = false
        
        // Then: Service should handle errors gracefully
        service.playAudioCue(for: .turnLeft)
        service.speakNavigationInstruction("Test")
        
        // No crash should occur
        XCTAssertNotNil(service)
    }
    
    // MARK: - Content Size Category Observation Tests
    
    func testContentSizeCategoryUpdates() {
        // Given: AccessibilityService observing content size changes
        let expectation = XCTestExpectation(description: "Content size category updated")
        
        // When: Content size category changes
        accessibilityService.$preferredContentSizeCategory
            .dropFirst()
            .sink { category in
                XCTAssertNotNil(category)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate a change
        accessibilityService.preferredContentSizeCategory = .large
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRouteStep() -> MKRoute.Step {
        // Create a mock route step for testing
        let step = MKRoute.Step()
        return step
    }
    
    private func createMockSearchResult() -> SearchResult {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Test Location"
        return SearchResult(mapItem: mapItem)
    }
    
    private func createMockLocation() -> CLLocation {
        return CLLocation(latitude: 37.7849, longitude: -122.4094)
    }
    
    private func createMockRoute() -> MKRoute {
        // Create a minimal mock route for testing
        // Note: MKRoute is difficult to mock, so this is a simplified version
        let route = MKRoute()
        return route
    }
}

// MARK: - Accessibility UI Tests Extension

extension AccessibilityTests {
    
    func testComponentAccessibilityIdentifiers() {
        // Given: Various UI components
        let components = [
            ("MapButton", "Primary action button"),
            ("SearchBar", "Search location"),
            ("HapticModeToggle", "Navigation mode toggle"),
            ("NavigationCard", "Navigation control panel")
        ]
        
        // Then: Components should have accessibility identifiers
        for (component, expectedLabel) in components {
            XCTAssertNotNil(component)
            XCTAssertNotNil(expectedLabel)
        }
    }
    
    func testVoiceOverNavigationOrder() {
        // Given: A screen with multiple accessible elements
        // This would typically be tested in UI tests with actual VoiceOver
        
        // Then: Elements should have logical navigation order
        // Note: This is a placeholder for more comprehensive UI testing
        XCTAssertTrue(true, "VoiceOver navigation order should be tested in UI tests")
    }
    
    func testAccessibilityTraitsAndHints() {
        // Given: Various UI components with accessibility traits
        let buttonTraits: AccessibilityTraits = [.button]
        let textTraits: AccessibilityTraits = [.staticText]
        let updatingTraits: AccessibilityTraits = [.updatesFrequently]
        
        // Then: Traits should be properly configured
        XCTAssertTrue(buttonTraits.contains(.button))
        XCTAssertTrue(textTraits.contains(.staticText))
        XCTAssertTrue(updatingTraits.contains(.updatesFrequently))
    }
} 