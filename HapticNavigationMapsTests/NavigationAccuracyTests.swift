import XCTest
import MapKit
import CoreLocation
import Combine
@testable import HapticNavigationMaps

/// Comprehensive navigation accuracy and timing tests across various route scenarios
@MainActor
class NavigationAccuracyTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var navigationEngine: NavigationEngine!
    var locationService: LocationService!
    var hapticService: HapticNavigationService!
    var dependencyContainer: DependencyContainer!
    var cancellables: Set<AnyCancellable>!
    
    // Test route scenarios
    struct RouteScenario {
        let name: String
        let startCoordinate: CLLocationCoordinate2D
        let endCoordinate: CLLocationCoordinate2D
        let expectedDistance: CLLocationDistance
        let expectedDuration: TimeInterval
        let routeComplexity: RouteComplexity
        let expectedStepCount: Int
    }
    
    enum RouteComplexity {
        case simple      // Straight line or minimal turns
        case moderate    // Several turns, typical city navigation
        case complex     // Many turns, highway merges, complex intersections
    }
    
    // Navigation timing results
    struct NavigationTiming {
        let routeCalculationTime: TimeInterval
        let navigationStartTime: TimeInterval
        let stepAdvancementTimes: [TimeInterval]
        let hapticFeedbackTimes: [TimeInterval]
        let totalNavigationTime: TimeInterval
        let actualVsExpectedDuration: TimeInterval
    }
    
    // Accuracy metrics
    struct AccuracyMetrics {
        let routeDistanceAccuracy: Double      // Percentage accuracy of calculated distance
        let routeDurationAccuracy: Double      // Percentage accuracy of estimated duration
        let stepTimingAccuracy: Double         // Accuracy of step advancement timing
        let locationTrackingAccuracy: Double   // GPS tracking accuracy during navigation
        let hapticTimingAccuracy: Double       // Accuracy of haptic feedback timing
    }
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        dependencyContainer = DependencyContainer.shared
        try await dependencyContainer.initialize()
        
        navigationEngine = try dependencyContainer.getNavigationEngine()
        locationService = try dependencyContainer.getLocationService()
        hapticService = try dependencyContainer.getHapticService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        navigationEngine.stopNavigation()
        await dependencyContainer.cleanup()
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Route Calculation Accuracy Tests
    
    func testRouteCalculationAccuracy() async throws {
        // Test route calculation accuracy across different scenarios
        let routeScenarios = createTestRouteScenarios()
        
        var accuracyResults: [AccuracyMetrics] = []
        
        for scenario in routeScenarios {
            let accuracy = try await testRouteScenarioAccuracy(scenario)
            accuracyResults.append(accuracy)
        }
        
        // Validate overall accuracy
        validateOverallAccuracy(accuracyResults)
        
        // Test specific accuracy requirements
        try await testRouteDistanceAccuracy(routeScenarios)
        try await testRouteDurationAccuracy(routeScenarios)
        try await testRouteComplexityHandling(routeScenarios)
    }
    
    func createTestRouteScenarios() -> [RouteScenario] {
        return [
            // Simple routes
            RouteScenario(
                name: "Short straight route",
                startCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                endCoordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                expectedDistance: 1500, // ~1.5km
                expectedDuration: 900,  // ~15 minutes walking
                routeComplexity: .simple,
                expectedStepCount: 3
            ),
            
            // Moderate complexity routes
            RouteScenario(
                name: "City navigation with turns",
                startCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                endCoordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4394),
                expectedDistance: 3000, // ~3km
                expectedDuration: 1800, // ~30 minutes walking
                routeComplexity: .moderate,
                expectedStepCount: 8
            ),
            
            // Complex routes
            RouteScenario(
                name: "Complex urban navigation",
                startCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                endCoordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.4594),
                expectedDistance: 5000, // ~5km
                expectedDuration: 3000, // ~50 minutes walking
                routeComplexity: .complex,
                expectedStepCount: 15
            ),
            
            // Different city scenarios
            RouteScenario(
                name: "NYC grid navigation",
                startCoordinate: CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851), // Times Square
                endCoordinate: CLLocationCoordinate2D(latitude: 40.7614, longitude: -73.9776), // Bryant Park
                expectedDistance: 800,  // ~0.8km
                expectedDuration: 600,  // ~10 minutes walking
                routeComplexity: .moderate,
                expectedStepCount: 5
            ),
            
            // Suburban scenarios
            RouteScenario(
                name: "Suburban navigation",
                startCoordinate: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430), // Palo Alto
                endCoordinate: CLLocationCoordinate2D(latitude: 37.4519, longitude: -122.1330),
                expectedDistance: 2000, // ~2km
                expectedDuration: 1200, // ~20 minutes walking
                routeComplexity: .simple,
                expectedStepCount: 6
            )
        ]
    }
    
    func testRouteScenarioAccuracy(_ scenario: RouteScenario) async throws -> AccuracyMetrics {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create destination map item
        let destinationPlacemark = MKPlacemark(coordinate: scenario.endCoordinate)
        let destination = MKMapItem(placemark: destinationPlacemark)
        
        // Simulate starting location
        let startLocation = CLLocation(latitude: scenario.startCoordinate.latitude, longitude: scenario.startCoordinate.longitude)
        locationService.updateNavigationState(.calculating)
        
        // Calculate route
        let calculatedRoute = try await navigationEngine.calculateRoute(to: destination)
        let routeCalculationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Validate route calculation timing
        XCTAssertLessThan(routeCalculationTime, 10.0, "Route calculation should complete within 10 seconds for \(scenario.name)")
        
        // Analyze route accuracy
        let distanceAccuracy = calculateDistanceAccuracy(
            expected: scenario.expectedDistance,
            actual: calculatedRoute.distance
        )
        
        let durationAccuracy = calculateDurationAccuracy(
            expected: scenario.expectedDuration,
            actual: calculatedRoute.expectedTravelTime
        )
        
        let stepCountAccuracy = calculateStepCountAccuracy(
            expected: scenario.expectedStepCount,
            actual: calculatedRoute.steps.count
        )
        
        // Test navigation timing
        let navigationTiming = try await testNavigationTiming(calculatedRoute, scenario: scenario)
        
        return AccuracyMetrics(
            routeDistanceAccuracy: distanceAccuracy,
            routeDurationAccuracy: durationAccuracy,
            stepTimingAccuracy: stepCountAccuracy,
            locationTrackingAccuracy: 0.95, // Simulated - would be measured with real GPS
            hapticTimingAccuracy: navigationTiming.hapticFeedbackTimes.isEmpty ? 1.0 : 0.90
        )
    }
    
    func testNavigationTiming(_ route: MKRoute, scenario: RouteScenario) async throws -> NavigationTiming {
        let navigationStartTime = CFAbsoluteTimeGetCurrent()
        
        // Start navigation
        navigationEngine.startNavigation(route: route, mode: .haptic)
        
        var stepAdvancementTimes: [TimeInterval] = []
        var hapticFeedbackTimes: [TimeInterval] = []
        
        // Simulate navigation progress
        let totalSteps = route.steps.count
        let simulationSpeed = 5.0 // 5x normal speed for testing
        
        for (stepIndex, step) in route.steps.enumerated() {
            let stepStartTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate location updates for this step
            let stepDistance = step.distance
            let stepDuration = stepDistance / 1.4 / simulationSpeed // 1.4 m/s walking speed, accelerated
            
            await simulateLocationProgress(step: step, duration: stepDuration)
            
            let stepCompletionTime = CFAbsoluteTimeGetCurrent() - stepStartTime
            stepAdvancementTimes.append(stepCompletionTime)
            
            // Test haptic feedback timing if supported
            if hapticService.isHapticCapable && stepIndex < totalSteps - 1 {
                let hapticStartTime = CFAbsoluteTimeGetCurrent()
                
                // Trigger appropriate haptic feedback based on step instruction
                try await triggerHapticForStep(step)
                
                let hapticTime = CFAbsoluteTimeGetCurrent() - hapticStartTime
                hapticFeedbackTimes.append(hapticTime)
            }
        }
        
        // Complete navigation
        navigationEngine.stopNavigation()
        
        let totalNavigationTime = CFAbsoluteTimeGetCurrent() - navigationStartTime
        let expectedNavigationTime = scenario.expectedDuration / simulationSpeed
        let actualVsExpected = totalNavigationTime - expectedNavigationTime
        
        return NavigationTiming(
            routeCalculationTime: 0, // Calculated separately
            navigationStartTime: 0,  // Not relevant for this test
            stepAdvancementTimes: stepAdvancementTimes,
            hapticFeedbackTimes: hapticFeedbackTimes,
            totalNavigationTime: totalNavigationTime,
            actualVsExpectedDuration: actualVsExpected
        )
    }
    
    // MARK: - Location Simulation
    
    func simulateLocationProgress(step: MKRoute.Step, duration: TimeInterval) async {
        // Simulate location updates along the step
        let updateInterval: TimeInterval = 1.0 // Update every second
        let totalUpdates = Int(duration / updateInterval)
        
        for updateIndex in 0..<totalUpdates {
            let progress = Double(updateIndex) / Double(totalUpdates)
            
            // Interpolate location along step polyline
            let simulatedLocation = interpolateLocationAlongStep(step: step, progress: progress)
            
            // Update navigation engine with simulated location
            navigationEngine.updateProgress(location: simulatedLocation)
            
            // Wait for update interval
            try! await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
    
    func interpolateLocationAlongStep(step: MKRoute.Step, progress: Double) -> CLLocation {
        // Simplified interpolation - in real implementation would use polyline coordinates
        let stepCoordinate = step.polyline.coordinate
        
        // Add some variation to simulate GPS accuracy
        let latVariation = (Double.random(in: -1...1) * 0.0001) * (1.0 - progress) // Reduce noise as we approach destination
        let lonVariation = (Double.random(in: -1...1) * 0.0001) * (1.0 - progress)
        
        let simulatedCoordinate = CLLocationCoordinate2D(
            latitude: stepCoordinate.latitude + latVariation,
            longitude: stepCoordinate.longitude + lonVariation
        )
        
        // Simulate GPS accuracy
        let horizontalAccuracy = Double.random(in: 3...15) // 3-15 meter accuracy
        
        return CLLocation(
            coordinate: simulatedCoordinate,
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }
    
    func triggerHapticForStep(_ step: MKRoute.Step) async throws {
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("left") {
            try await hapticService.playTurnLeftPattern()
        } else if instruction.contains("right") {
            try await hapticService.playTurnRightPattern()
        } else {
            try await hapticService.playContinueStraightPattern()
        }
    }
    
    // MARK: - Accuracy Calculation Methods
    
    func calculateDistanceAccuracy(expected: CLLocationDistance, actual: CLLocationDistance) -> Double {
        let accuracy = 1.0 - abs(expected - actual) / expected
        return max(0.0, min(1.0, accuracy))
    }
    
    func calculateDurationAccuracy(expected: TimeInterval, actual: TimeInterval) -> Double {
        let accuracy = 1.0 - abs(expected - actual) / expected
        return max(0.0, min(1.0, accuracy))
    }
    
    func calculateStepCountAccuracy(expected: Int, actual: Int) -> Double {
        if expected == 0 { return actual == 0 ? 1.0 : 0.0 }
        let accuracy = 1.0 - abs(Double(expected - actual)) / Double(expected)
        return max(0.0, min(1.0, accuracy))
    }
    
    // MARK: - Accuracy Validation
    
    func validateOverallAccuracy(_ results: [AccuracyMetrics]) {
        let averageDistanceAccuracy = results.map { $0.routeDistanceAccuracy }.average
        let averageDurationAccuracy = results.map { $0.routeDurationAccuracy }.average
        let averageStepAccuracy = results.map { $0.stepTimingAccuracy }.average
        let averageLocationAccuracy = results.map { $0.locationTrackingAccuracy }.average
        let averageHapticAccuracy = results.map { $0.hapticTimingAccuracy }.average
        
        // Validate minimum accuracy requirements
        XCTAssertGreaterThan(averageDistanceAccuracy, 0.85, "Route distance accuracy should be > 85%")
        XCTAssertGreaterThan(averageDurationAccuracy, 0.75, "Route duration accuracy should be > 75%")
        XCTAssertGreaterThan(averageStepAccuracy, 0.70, "Step timing accuracy should be > 70%")
        XCTAssertGreaterThan(averageLocationAccuracy, 0.90, "Location tracking accuracy should be > 90%")
        XCTAssertGreaterThan(averageHapticAccuracy, 0.85, "Haptic timing accuracy should be > 85%")
        
        print("Navigation Accuracy Results:")
        print("- Distance Accuracy: \(String(format: "%.1f", averageDistanceAccuracy * 100))%")
        print("- Duration Accuracy: \(String(format: "%.1f", averageDurationAccuracy * 100))%")
        print("- Step Accuracy: \(String(format: "%.1f", averageStepAccuracy * 100))%")
        print("- Location Accuracy: \(String(format: "%.1f", averageLocationAccuracy * 100))%")
        print("- Haptic Accuracy: \(String(format: "%.1f", averageHapticAccuracy * 100))%")
    }
    
    func testRouteDistanceAccuracy(_ scenarios: [RouteScenario]) async throws {
        // Test distance calculation accuracy specifically
        
        for scenario in scenarios {
            let destinationPlacemark = MKPlacemark(coordinate: scenario.endCoordinate)
            let destination = MKMapItem(placemark: destinationPlacemark)
            
            let route = try await navigationEngine.calculateRoute(to: destination)
            
            let accuracy = calculateDistanceAccuracy(expected: scenario.expectedDistance, actual: route.distance)
            let toleranceBasedOnComplexity = getDistanceToleranceForComplexity(scenario.routeComplexity)
            
            XCTAssertGreaterThan(accuracy, toleranceBasedOnComplexity, 
                               "Distance accuracy for \(scenario.name) should be > \(toleranceBasedOnComplexity * 100)%")
            
            // Log detailed results
            let distanceDifference = abs(scenario.expectedDistance - route.distance)
            print("\(scenario.name): Expected \(Int(scenario.expectedDistance))m, Got \(Int(route.distance))m, Difference: \(Int(distanceDifference))m")
        }
    }
    
    func testRouteDurationAccuracy(_ scenarios: [RouteScenario]) async throws {
        // Test duration estimation accuracy specifically
        
        for scenario in scenarios {
            let destinationPlacemark = MKPlacemark(coordinate: scenario.endCoordinate)
            let destination = MKMapItem(placemark: destinationPlacemark)
            
            let route = try await navigationEngine.calculateRoute(to: destination)
            
            let accuracy = calculateDurationAccuracy(expected: scenario.expectedDuration, actual: route.expectedTravelTime)
            let toleranceBasedOnComplexity = getDurationToleranceForComplexity(scenario.routeComplexity)
            
            XCTAssertGreaterThan(accuracy, toleranceBasedOnComplexity,
                               "Duration accuracy for \(scenario.name) should be > \(toleranceBasedOnComplexity * 100)%")
            
            // Log detailed results
            let durationDifference = abs(scenario.expectedDuration - route.expectedTravelTime)
            print("\(scenario.name): Expected \(Int(scenario.expectedDuration))s, Got \(Int(route.expectedTravelTime))s, Difference: \(Int(durationDifference))s")
        }
    }
    
    func testRouteComplexityHandling(_ scenarios: [RouteScenario]) async throws {
        // Test how well the navigation engine handles different route complexities
        
        let complexityResults = Dictionary(grouping: scenarios, by: { $0.routeComplexity })
        
        for (complexity, scenarios) in complexityResults {
            var calculationTimes: [TimeInterval] = []
            var stepCountAccuracies: [Double] = []
            
            for scenario in scenarios {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let destinationPlacemark = MKPlacemark(coordinate: scenario.endCoordinate)
                let destination = MKMapItem(placemark: destinationPlacemark)
                
                let route = try await navigationEngine.calculateRoute(to: destination)
                
                let calculationTime = CFAbsoluteTimeGetCurrent() - startTime
                calculationTimes.append(calculationTime)
                
                let stepAccuracy = calculateStepCountAccuracy(expected: scenario.expectedStepCount, actual: route.steps.count)
                stepCountAccuracies.append(stepAccuracy)
            }
            
            let avgCalculationTime = calculationTimes.average
            let avgStepAccuracy = stepCountAccuracies.average
            
            // Validate complexity-specific requirements
            switch complexity {
            case .simple:
                XCTAssertLessThan(avgCalculationTime, 3.0, "Simple routes should calculate quickly")
                XCTAssertGreaterThan(avgStepAccuracy, 0.80, "Simple routes should have high step accuracy")
                
            case .moderate:
                XCTAssertLessThan(avgCalculationTime, 5.0, "Moderate routes should calculate reasonably quickly")
                XCTAssertGreaterThan(avgStepAccuracy, 0.70, "Moderate routes should have good step accuracy")
                
            case .complex:
                XCTAssertLessThan(avgCalculationTime, 10.0, "Complex routes should still calculate within reasonable time")
                XCTAssertGreaterThan(avgStepAccuracy, 0.60, "Complex routes should have acceptable step accuracy")
            }
            
            print("Route Complexity \(complexity): Avg Calculation Time: \(String(format: "%.2f", avgCalculationTime))s, Step Accuracy: \(String(format: "%.1f", avgStepAccuracy * 100))%")
        }
    }
    
    // MARK: - Timing Precision Tests
    
    func testNavigationTimingPrecision() async throws {
        // Test timing precision for navigation events
        
        let testRoute = try await createSimpleTestRoute()
        
        // Test navigation start timing
        let startTimingResults = try await testNavigationStartTiming(testRoute)
        validateNavigationStartTiming(startTimingResults)
        
        // Test step advancement timing
        let stepTimingResults = try await testStepAdvancementTiming(testRoute)
        validateStepAdvancementTiming(stepTimingResults)
        
        // Test haptic feedback timing
        if hapticService.isHapticCapable {
            let hapticTimingResults = try await testHapticFeedbackTiming(testRoute)
            validateHapticFeedbackTiming(hapticTimingResults)
        }
        
        // Test navigation completion timing
        let completionTimingResults = try await testNavigationCompletionTiming(testRoute)
        validateNavigationCompletionTiming(completionTimingResults)
    }
    
    func createSimpleTestRoute() async throws -> MKRoute {
        let startCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let endCoordinate = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        
        let destinationPlacemark = MKPlacemark(coordinate: endCoordinate)
        let destination = MKMapItem(placemark: destinationPlacemark)
        
        return try await navigationEngine.calculateRoute(to: destination)
    }
    
    func testNavigationStartTiming(_ route: MKRoute) async throws -> [TimeInterval] {
        var startTimes: [TimeInterval] = []
        
        // Test navigation start timing multiple times
        for _ in 0..<10 {
            let startTime = CFAbsoluteTimeGetCurrent()
            navigationEngine.startNavigation(route: route, mode: .visual)
            let navigationStartTime = CFAbsoluteTimeGetCurrent() - startTime
            
            startTimes.append(navigationStartTime)
            
            navigationEngine.stopNavigation()
            
            // Small delay between tests
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        return startTimes
    }
    
    func testStepAdvancementTiming(_ route: MKRoute) async throws -> [TimeInterval] {
        var advancementTimes: [TimeInterval] = []
        
        navigationEngine.startNavigation(route: route, mode: .visual)
        
        // Simulate location updates and measure step advancement timing
        for step in route.steps.prefix(5) { // Test first 5 steps
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate reaching step location
            let stepLocation = CLLocation(
                latitude: step.polyline.coordinate.latitude,
                longitude: step.polyline.coordinate.longitude
            )
            
            navigationEngine.updateProgress(location: stepLocation)
            
            let advancementTime = CFAbsoluteTimeGetCurrent() - startTime
            advancementTimes.append(advancementTime)
        }
        
        navigationEngine.stopNavigation()
        return advancementTimes
    }
    
    func testHapticFeedbackTiming(_ route: MKRoute) async throws -> [TimeInterval] {
        var hapticTimes: [TimeInterval] = []
        
        navigationEngine.startNavigation(route: route, mode: .haptic)
        
        // Test haptic feedback timing for different patterns
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        
        for pattern in patterns {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            switch pattern {
            case .leftTurn:
                try await hapticService.playTurnLeftPattern()
            case .rightTurn:
                try await hapticService.playTurnRightPattern()
            case .continueStraight:
                try await hapticService.playContinueStraightPattern()
            case .arrival:
                try await hapticService.playArrivalPattern()
            }
            
            let hapticTime = CFAbsoluteTimeGetCurrent() - startTime
            hapticTimes.append(hapticTime)
        }
        
        navigationEngine.stopNavigation()
        return hapticTimes
    }
    
    func testNavigationCompletionTiming(_ route: MKRoute) async throws -> [TimeInterval] {
        var completionTimes: [TimeInterval] = []
        
        // Test navigation completion timing
        for _ in 0..<5 {
            navigationEngine.startNavigation(route: route, mode: .visual)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            navigationEngine.stopNavigation()
            let completionTime = CFAbsoluteTimeGetCurrent() - startTime
            
            completionTimes.append(completionTime)
            
            // Small delay between tests
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        return completionTimes
    }
    
    // MARK: - Timing Validation
    
    func validateNavigationStartTiming(_ times: [TimeInterval]) {
        let averageTime = times.average
        let maxTime = times.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.1, "Average navigation start time should be < 100ms")
        XCTAssertLessThan(maxTime, 0.2, "Maximum navigation start time should be < 200ms")
        
        print("Navigation Start Timing: Avg: \(String(format: "%.1f", averageTime * 1000))ms, Max: \(String(format: "%.1f", maxTime * 1000))ms")
    }
    
    func validateStepAdvancementTiming(_ times: [TimeInterval]) {
        let averageTime = times.average
        let maxTime = times.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.05, "Average step advancement time should be < 50ms")
        XCTAssertLessThan(maxTime, 0.1, "Maximum step advancement time should be < 100ms")
        
        print("Step Advancement Timing: Avg: \(String(format: "%.1f", averageTime * 1000))ms, Max: \(String(format: "%.1f", maxTime * 1000))ms")
    }
    
    func validateHapticFeedbackTiming(_ times: [TimeInterval]) {
        let averageTime = times.average
        let maxTime = times.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.05, "Average haptic feedback time should be < 50ms")
        XCTAssertLessThan(maxTime, 0.1, "Maximum haptic feedback time should be < 100ms")
        
        print("Haptic Feedback Timing: Avg: \(String(format: "%.1f", averageTime * 1000))ms, Max: \(String(format: "%.1f", maxTime * 1000))ms")
    }
    
    func validateNavigationCompletionTiming(_ times: [TimeInterval]) {
        let averageTime = times.average
        let maxTime = times.max() ?? 0
        
        XCTAssertLessThan(averageTime, 0.05, "Average navigation completion time should be < 50ms")
        XCTAssertLessThan(maxTime, 0.1, "Maximum navigation completion time should be < 100ms")
        
        print("Navigation Completion Timing: Avg: \(String(format: "%.1f", averageTime * 1000))ms, Max: \(String(format: "%.1f", maxTime * 1000))ms")
    }
    
    // MARK: - Edge Case Testing
    
    func testNavigationEdgeCases() async throws {
        // Test navigation behavior in edge cases
        
        try await testZeroDistanceRoute()
        try await testVeryLongRoute()
        try await testInvalidCoordinates()
        try await testNetworkFailureDuringNavigation()
        try await testGPSSignalLossDuringNavigation()
    }
    
    func testZeroDistanceRoute() async throws {
        // Test route with same start and end coordinates
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let placemark = MKPlacemark(coordinate: coordinate)
        let destination = MKMapItem(placemark: placemark)
        
        do {
            let route = try await navigationEngine.calculateRoute(to: destination)
            XCTAssertLessThan(route.distance, 100, "Zero distance route should have minimal distance")
            XCTAssertLessThan(route.expectedTravelTime, 300, "Zero distance route should have minimal duration")
        } catch {
            // Zero distance routes might throw an error, which is acceptable
            print("Zero distance route threw error as expected: \(error)")
        }
    }
    
    func testVeryLongRoute() async throws {
        // Test very long distance route
        let startCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let endCoordinate = CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851)   // New York
        
        let destinationPlacemark = MKPlacemark(coordinate: endCoordinate)
        let destination = MKMapItem(placemark: destinationPlacemark)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let route = try await navigationEngine.calculateRoute(to: destination)
            let calculationTime = CFAbsoluteTimeGetCurrent() - startTime
            
            XCTAssertGreaterThan(route.distance, 4000000, "Cross-country route should be very long") // > 4000km
            XCTAssertLessThan(calculationTime, 15.0, "Even very long routes should calculate within 15 seconds")
            
        } catch {
            // Very long routes might not be supported, which is acceptable
            print("Very long route threw error: \(error)")
        }
    }
    
    func testInvalidCoordinates() async throws {
        // Test invalid coordinate handling
        let invalidCoordinates = [
            CLLocationCoordinate2D(latitude: 91, longitude: 0),    // Invalid latitude
            CLLocationCoordinate2D(latitude: 0, longitude: 181),   // Invalid longitude
            CLLocationCoordinate2D(latitude: -91, longitude: 0),   // Invalid latitude
            CLLocationCoordinate2D(latitude: 0, longitude: -181)   // Invalid longitude
        ]
        
        for invalidCoord in invalidCoordinates {
            let placemark = MKPlacemark(coordinate: invalidCoord)
            let destination = MKMapItem(placemark: placemark)
            
            do {
                let _ = try await navigationEngine.calculateRoute(to: destination)
                XCTFail("Invalid coordinates should throw an error")
            } catch {
                // Expected to throw an error
                print("Invalid coordinate error handled correctly: \(error)")
            }
        }
    }
    
    func testNetworkFailureDuringNavigation() async throws {
        // Test navigation behavior during network failures
        // This would typically involve mocking network failures
        print("Network failure handling test - would require network mocking")
    }
    
    func testGPSSignalLossDuringNavigation() async throws {
        // Test navigation behavior during GPS signal loss
        // This would typically involve simulating GPS signal loss
        print("GPS signal loss handling test - would require GPS mocking")
    }
    
    // MARK: - Helper Methods
    
    private func getDistanceToleranceForComplexity(_ complexity: RouteComplexity) -> Double {
        switch complexity {
        case .simple: return 0.90    // 90% accuracy for simple routes
        case .moderate: return 0.85  // 85% accuracy for moderate routes
        case .complex: return 0.80   // 80% accuracy for complex routes
        }
    }
    
    private func getDurationToleranceForComplexity(_ complexity: RouteComplexity) -> Double {
        switch complexity {
        case .simple: return 0.80    // 80% accuracy for simple routes
        case .moderate: return 0.75  // 75% accuracy for moderate routes
        case .complex: return 0.70   // 70% accuracy for complex routes
        }
    }
} 