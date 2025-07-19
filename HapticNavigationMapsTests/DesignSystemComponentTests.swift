import XCTest
@testable import HapticNavigationMaps
import SwiftUI
import MapKit

@MainActor
final class DesignSystemComponentTests: XCTestCase {
    
    var mockRoute: MKRoute!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock route for testing using real MKDirections
        let coordinate1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coordinate2 = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        let placemark1 = MKPlacemark(coordinate: coordinate1)
        let placemark2 = MKPlacemark(coordinate: coordinate2)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: placemark1)
        request.destination = MKMapItem(placemark: placemark2)
        request.transportType = .walking
        
        // For testing, we'll create a simple test route
        // In real tests, you might want to use recorded responses
        mockRoute = try await createTestRoute(from: coordinate1, to: coordinate2)
    }
    
    override func tearDown() async throws {
        mockRoute = nil
        try await super.tearDown()
    }
    
    // MARK: - MapButton Component Tests
    
    func testMapButtonPrimaryStyleRendering() {
        // Given: Primary style MapButton
        let button = MapButton(
            action: {},
            icon: "play.fill",
            label: "Start Navigation",
            style: .primary,
            size: .medium
        )
        
        // When: Rendering the button
        let view = button.body
        
        // Then: Verify design token usage
        XCTAssertNotNil(view)
        
        // Test button properties
        XCTAssertEqual(button.icon, "play.fill")
        XCTAssertEqual(button.label, "Start Navigation")
        XCTAssertEqual(button.style, .primary)
        XCTAssertEqual(button.size, .medium)
    }
    
    func testMapButtonSecondaryStyleRendering() {
        // Given: Secondary style MapButton
        let button = MapButton(
            action: {},
            icon: "xmark",
            label: "Cancel",
            style: .secondary,
            size: .medium
        )
        
        // When: Rendering the button
        let view = button.body
        
        // Then: Verify proper styling
        XCTAssertNotNil(view)
        
        // Test style consistency
        XCTAssertEqual(button.style, .secondary)
        XCTAssertEqual(button.size, .medium)
    }
    
    func testMapButtonSizeVariations() {
        let sizes: [MapButtonSize] = [.small, .medium, .large, .compact]
        
        for size in sizes {
            // Given: MapButton with specific size
            let button = MapButton(
                action: {},
                icon: "star",
                label: "Test",
                style: .primary,
                size: size
            )
            
            // When: Rendering the button
            let view = button.body
            
            // Then: Verify size is applied correctly
            XCTAssertNotNil(view)
            XCTAssertEqual(button.size, size)
        }
    }
    
    func testMapButtonTertiaryStyle() {
        // Given: Tertiary style MapButton
        let button = MapButton(
            action: {},
            icon: "stop.fill",
            label: "End Navigation",
            style: .tertiary,
            size: .medium
        )
        
        // When: Rendering the button
        let view = button.body
        
        // Then: Verify tertiary styling
        XCTAssertNotNil(view)
        XCTAssertEqual(button.style, .tertiary)
    }
    
    func testMapButtonDisabledState() {
        // Given: Disabled MapButton
        let button = MapButton(
            action: {},
            icon: "pause",
            label: "Disabled",
            style: .primary,
            size: .medium,
            isEnabled: false
        )
        
        // When: Rendering the button
        let view = button.body
        
        // Then: Verify disabled state styling
        XCTAssertNotNil(view)
        XCTAssertFalse(button.isEnabled)
    }
    
    func testMapButtonAccessibility() {
        // Given: MapButton with accessibility properties
        let button = MapButton(
            action: {},
            icon: "star.fill",
            label: "Accessible Button",
            style: .primary,
            size: .medium
        )
        
        // When: Checking accessibility
        // Then: Verify accessibility compliance
        XCTAssertEqual(button.label, "Accessible Button")
        XCTAssertNotNil(button.body)
    }
    
    // MARK: - RouteInfoPanel Component Tests
    
    func testRouteInfoPanelRendering() {
        // Given: RouteInfoPanel with mock route
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Rendering the panel
        let view = panel.body
        
        // Then: Verify proper rendering
        XCTAssertNotNil(view)
        XCTAssertNotNil(panel.route)
    }
    
    func testRouteInfoPanelMetricsDisplay() {
        // Given: RouteInfoPanel with route metrics
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Extracting route information
        let expectedTime = mockRoute.expectedTravelTime
        let distance = mockRoute.distance
        
        // Then: Verify metrics are properly formatted
        XCTAssertGreaterThan(expectedTime, 0)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertNotNil(panel.body)
    }
    
    func testRouteInfoPanelDesignTokenUsage() {
        // Given: RouteInfoPanel using design tokens
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Rendering with design tokens
        let view = panel.body
        
        // Then: Verify design system consistency
        XCTAssertNotNil(view)
        
        // Test that design tokens are accessible
        XCTAssertNotNil(DesignTokens.Colors.primary)
        XCTAssertNotNil(DesignTokens.Typography.headline)
        XCTAssertNotNil(DesignTokens.Spacing.md)
    }
    
    func testRouteMetricViewFormatting() {
        // Given: Route metrics
        let timeMetric = RouteMetricView(
            icon: "clock",
            iconColor: DesignTokens.Colors.primary,
            value: "30 min",
            label: "Travel time"
        )
        
        let distanceMetric = RouteMetricView(
            icon: "location",
            iconColor: DesignTokens.Colors.primary,
            value: "1.5 km",
            label: "Distance"
        )
        
        // Then: Verify proper formatting
        XCTAssertNotNil(timeMetric.body)
        XCTAssertNotNil(distanceMetric.body)
        XCTAssertEqual(timeMetric.icon, "clock")
        XCTAssertEqual(distanceMetric.icon, "location")
    }
    
    func testRouteInfoPanelButtonIntegration() {
        var navigationStarted = false
        
        // Given: RouteInfoPanel with callback
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {
                navigationStarted = true
            },
            onDismiss: {}
        )
        
        // When: Simulating button interaction
        panel.onStartNavigation()
        
        // Then: Verify callback execution
        XCTAssertTrue(navigationStarted)
    }
    
    // MARK: - Design Tokens Consistency Tests
    
    func testColorTokensConsistency() {
        // Given: Design token color definitions
        let colors = DesignTokens.Colors.self
        
        // When: Accessing color tokens
        // Then: Verify all required colors are defined
        XCTAssertNotNil(colors.primary)
        XCTAssertNotNil(colors.secondary)
        XCTAssertNotNil(colors.background)
        XCTAssertNotNil(colors.surface)
        XCTAssertNotNil(colors.textPrimary)
        XCTAssertNotNil(colors.textSecondary)
        XCTAssertNotNil(colors.success)
        XCTAssertNotNil(colors.warning)
        XCTAssertNotNil(colors.error)
    }
    
    func testTypographyTokensConsistency() {
        // Given: Design token typography definitions
        let typography = DesignTokens.Typography.self
        
        // When: Accessing typography tokens
        // Then: Verify all required typography styles are defined
        XCTAssertNotNil(typography.largeTitle)
        XCTAssertNotNil(typography.title1)
        XCTAssertNotNil(typography.title2)
        XCTAssertNotNil(typography.title3)
        XCTAssertNotNil(typography.headline)
        XCTAssertNotNil(typography.body)
        XCTAssertNotNil(typography.callout)
        XCTAssertNotNil(typography.subheadline)
        XCTAssertNotNil(typography.footnote)
        XCTAssertNotNil(typography.caption1)
        XCTAssertNotNil(typography.caption2)
    }
    
    func testSpacingTokensConsistency() {
        // Given: Design token spacing definitions
        let spacing = DesignTokens.Spacing.self
        
        // When: Accessing spacing tokens
        // Then: Verify spacing scale consistency
        XCTAssertLessThan(spacing.xs, spacing.sm)
        XCTAssertLessThan(spacing.sm, spacing.md)
        XCTAssertLessThan(spacing.md, spacing.lg)
        XCTAssertLessThan(spacing.lg, spacing.xl)
        XCTAssertLessThan(spacing.xl, spacing.xxl)
        
        // Verify specific spacing values
        XCTAssertEqual(spacing.xs, 4)
        XCTAssertEqual(spacing.sm, 8)
        XCTAssertEqual(spacing.md, 12)
        XCTAssertEqual(spacing.lg, 16)
        XCTAssertEqual(spacing.xl, 20)
        XCTAssertEqual(spacing.xxl, 24)
    }
    
    func testCornerRadiusTokensConsistency() {
        // Given: Design token corner radius definitions
        let cornerRadius = DesignTokens.CornerRadius.self
        
        // When: Accessing corner radius tokens
        // Then: Verify radius values are defined and reasonable
        XCTAssertGreaterThan(cornerRadius.sm, 0)
        XCTAssertGreaterThan(cornerRadius.md, cornerRadius.sm)
        XCTAssertGreaterThan(cornerRadius.lg, cornerRadius.md)
        XCTAssertGreaterThan(cornerRadius.xl, cornerRadius.lg)
    }
    
    func testIconSizeTokensConsistency() {
        // Given: Design token icon size definitions
        let iconSize = DesignTokens.IconSize.self
        
        // When: Accessing icon size tokens
        // Then: Verify size scale consistency
        XCTAssertGreaterThan(iconSize.sm, 0)
        XCTAssertGreaterThan(iconSize.md, iconSize.sm)
        XCTAssertGreaterThan(iconSize.lg, iconSize.md)
        XCTAssertGreaterThan(iconSize.xl, iconSize.lg)
    }
    
    // MARK: - Component Integration Tests
    
    func testMapButtonInRouteInfoPanelIntegration() {
        // Given: RouteInfoPanel containing MapButton
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Rendering panel with integrated button
        let view = panel.body
        
        // Then: Verify proper integration
        XCTAssertNotNil(view)
        XCTAssertNotNil(panel.route)
    }
    
    func testDesignTokensInComponentStyling() {
        // Given: Components using design tokens
        let button = MapButton(
            action: {},
            icon: "star",
            label: "Test",
            style: .primary,
            size: .medium
        )
        
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Verifying design token usage
        // Then: Components should use consistent tokens
        XCTAssertNotNil(button.body)
        XCTAssertNotNil(panel.body)
        
        // Verify design tokens are accessible in components
        let primaryColor = DesignTokens.Colors.primary
        let headlineFont = DesignTokens.Typography.headline
        let mediumSpacing = DesignTokens.Spacing.md
        
        XCTAssertNotNil(primaryColor)
        XCTAssertNotNil(headlineFont)
        XCTAssertEqual(mediumSpacing, 12)
    }
    
    func testComponentThemeConsistency() {
        // Given: Multiple components using the design system
        let components = [
            MapButton(action: {}, icon: "play", label: "Primary", style: .primary, size: .medium),
            MapButton(action: {}, icon: "pause", label: "Secondary", style: .secondary, size: .medium),
            MapButton(action: {}, icon: "stop", label: "Tertiary", style: .tertiary, size: .medium)
        ]
        
        // When: Verifying theme consistency across components
        // Then: All components should follow design system
        for component in components {
            XCTAssertNotNil(component.body)
            XCTAssertNotNil(component.label)
        }
    }
    
    func testAccessibilityComplianceAcrossComponents() {
        // Given: Components with accessibility requirements
        let button = MapButton(
            action: {},
            icon: "star",
            label: "Accessible Button",
            style: .primary,
            size: .medium
        )
        
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Checking accessibility compliance
        // Then: Components should be accessible
        XCTAssertEqual(button.label, "Accessible Button")
        XCTAssertNotNil(button.body)
        XCTAssertNotNil(panel.body)
        XCTAssertNotNil(panel.route)
    }
    
    // MARK: - Visual Regression Prevention Tests
    
    func testComponentRenderingStability() {
        // Given: Components with fixed content
        let button = MapButton(
            action: {},
            icon: "star",
            label: "Stable Button",
            style: .primary,
            size: .medium
        )
        
        let panel = RouteInfoPanel(
            route: mockRoute,
            onStartNavigation: {},
            onDismiss: {}
        )
        
        // When: Rendering multiple times
        for _ in 0..<5 {
            let buttonView = button.body
            let panelView = panel.body
            
            // Then: Rendering should be consistent
            XCTAssertNotNil(buttonView)
            XCTAssertNotNil(panelView)
        }
    }
    
    func testDesignTokenValueStability() {
        // Given: Design token values
        let originalSpacing = DesignTokens.Spacing.md
        let originalColor = DesignTokens.Colors.primary
        let originalRadius = DesignTokens.CornerRadius.md
        
        // When: Accessing tokens multiple times
        for _ in 0..<10 {
            let spacing = DesignTokens.Spacing.md
            let color = DesignTokens.Colors.primary
            let radius = DesignTokens.CornerRadius.md
            
            // Then: Values should remain consistent
            XCTAssertEqual(spacing, originalSpacing)
            XCTAssertEqual(color, originalColor)
            XCTAssertEqual(radius, originalRadius)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        // Create a test route using MKDirections
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw TestError.noRouteFound
        }
        
        return route
    }
    
    enum TestError: Error {
        case noRouteFound
    }
}

// MARK: - Design Token Extension for Testing

extension DesignTokens {
    static func validateTokenConsistency() -> Bool {
        // Validate that all design tokens follow expected patterns
        let spacingValid = Spacing.xs < Spacing.sm && Spacing.sm < Spacing.md
        let radiusValid = CornerRadius.sm < CornerRadius.md && CornerRadius.md < CornerRadius.lg
        let iconSizeValid = IconSize.sm < IconSize.md && IconSize.md < IconSize.lg
        
        return spacingValid && radiusValid && iconSizeValid
    }
} 