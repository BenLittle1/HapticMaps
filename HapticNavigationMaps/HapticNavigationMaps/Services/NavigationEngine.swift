import Foundation
import MapKit
import CoreLocation
import Combine
import CoreHaptics

/// Navigation engine responsible for route calculation and navigation progress tracking
@MainActor
class NavigationEngine: NavigationEngineProtocol {
    // MARK: - Published Properties
    @Published private(set) var currentRoute: MKRoute?
    @Published private(set) var currentStep: MKRoute.Step?
    @Published private(set) var navigationState: NavigationState = .idle
    @Published private(set) var availableRoutes: [MKRoute] = []
    @Published private(set) var routeCalculationError: NavigationError?
    
    // MARK: - Private Properties
    private var currentStepIndex: Int = 0
    private var routeProgress: CLLocationDistance = 0
    private let stepProximityThreshold: CLLocationDistance = 50 // meters
    private var currentLocation: CLLocation?
    private var routeCalculationTask: Task<MKDirections.Response, Error>?
    
    // MARK: - Haptic Integration Properties
    private let hapticService: any HapticNavigationServiceProtocol
    private var lastHapticTriggerDistance: CLLocationDistance = 0
    private let hapticTriggerDistance: CLLocationDistance = 100 // meters before turn
    private let hapticMinimumInterval: TimeInterval = 5.0 // seconds between haptic cues
    private var lastHapticTime: Date = Date.distantPast
    private var hasTriggeredTurnHaptic = false
    
    // MARK: - Initialization
    init(hapticService: any HapticNavigationServiceProtocol) {
        self.hapticService = hapticService
    }
    
    convenience init() {
        self.init(hapticService: HapticNavigationService())
    }
    
    // MARK: - NavigationEngineProtocol Implementation
    
    /// Calculate route to destination using MKDirections with simplified, reliable logic
    func calculateRoute(to destination: MKMapItem) async throws -> MKRoute {
        print("🗺️ NavigationEngine: Starting route calculation to \(destination.name ?? "unknown destination")")
        
        // Cancel any existing route calculation
        cancelRouteCalculation()
        
        // Clear any previous errors
        routeCalculationError = nil
        
        // Set calculating state
        navigationState = .calculating
        print("🗺️ NavigationEngine: State set to calculating")
        
        // Ensure we have a current location
        guard let currentLocation = currentLocation else {
            print("🗺️ NavigationEngine: ERROR - No current location available")
            navigationState = .idle
            let error = NavigationError.noCurrentLocation
            routeCalculationError = error
            throw error
        }
        
        print("🗺️ NavigationEngine: Using current location: \(currentLocation.coordinate)")
        
        // Create and track the route calculation task
        let task = Task {
            try await withThrowingTaskGroup(of: MKDirections.Response.self) { group in
                // Add route calculation task
                group.addTask {
                    print("🗺️ NavigationEngine: Starting MKDirections request")
                    let request = MKDirections.Request()
                    request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
                    request.destination = destination
                    request.transportType = .walking
                    request.requestsAlternateRoutes = true
                    
                    let directions = MKDirections(request: request)
                    let response = try await directions.calculate()
                    print("🗺️ NavigationEngine: MKDirections completed with \(response.routes.count) routes")
                    return response
                }
                
                // Add simplified timeout
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                    print("🗺️ NavigationEngine: Route calculation timed out after 15 seconds")
                    throw NavigationError.routeCalculationTimeout
                }
                
                // Get first result and cancel the group
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }
        
        // Store task for cancellation
        routeCalculationTask = task
        
        do {
            // Wait for the route calculation to complete
            let directionsResponse = try await task.value
            
            guard !directionsResponse.routes.isEmpty else {
                print("🗺️ NavigationEngine: ERROR - No routes found in response")
                navigationState = .idle
                let error = NavigationError.noRouteFound
                routeCalculationError = error
                throw error
            }
            
            // Store all available routes
            availableRoutes = directionsResponse.routes
            currentRoute = directionsResponse.routes.first
            navigationState = .idle
            routeCalculationTask = nil
            
            print("🗺️ NavigationEngine: ✅ Route calculation successful! Found \(directionsResponse.routes.count) routes")
            print("🗺️ NavigationEngine: Primary route distance: \(directionsResponse.routes.first!.distance)m, time: \(directionsResponse.routes.first!.expectedTravelTime)s")
            
            return directionsResponse.routes.first!
            
        } catch {
            print("🗺️ NavigationEngine: ERROR - Route calculation failed: \(error)")
            
            // Always reset state on error
            navigationState = .idle
            routeCalculationTask = nil
            
            // Handle cancellation
            if error is CancellationError {
                routeCalculationError = NavigationError.calculationCanceled
                throw NavigationError.calculationCanceled
            }
            
            // Classify the error for better user feedback
            let classifiedError: NavigationError
            if let navError = error as? NavigationError {
                classifiedError = navError
            } else {
                classifiedError = classifyRouteCalculationError(error)
            }
            
            routeCalculationError = classifiedError
            print("🗺️ NavigationEngine: Classified error as: \(classifiedError)")
            throw classifiedError
        }
    }
    
    // MARK: - Private Methods - Route Calculation Error Handling
    
    private func classifyRouteCalculationError(_ error: Error) -> NavigationError {
        let nsError = error as NSError
        
        // Check for specific error codes that indicate different types of failures
        switch nsError.code {
        case NSURLErrorTimedOut, NSURLErrorCannotConnectToHost:
            return .routeCalculationTimeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkError(error)
        case NSURLErrorBadServerResponse, NSURLErrorCannotFindHost:
            return .serviceUnavailable
        case NSURLErrorResourceUnavailable:
            return .rateLimitExceeded
        default:
            // Check domain-specific errors
            if nsError.domain == MKErrorDomain {
                switch nsError.code {
                case Int(MKError.directionsNotFound.rawValue):
                    return .noRouteFound
                case Int(MKError.loadingThrottled.rawValue):
                    return .rateLimitExceeded
                case Int(MKError.serverFailure.rawValue):
                    return .serviceUnavailable
                default:
                    return .routeCalculationFailed(error)
                }
            }
            
            return .routeCalculationFailed(error)
        }
    }
    
    /// Start navigation with the provided route
    func startNavigation(route: MKRoute, mode: NavigationMode = .visual) {
        currentRoute = route
        currentStepIndex = 0
        routeProgress = 0
        
        // Set initial step
        if !route.steps.isEmpty {
            currentStep = route.steps[0]
        }
        
        // Initialize haptic engine if needed
        if mode == .haptic {
            initializeHapticEngineIfNeeded()
            hapticService.startNavigationBackgroundTask()
        }
        
        // Reset haptic state
        resetHapticState()
        
        navigationState = .navigating(mode: mode)
    }
    
    /// Set navigation mode during active navigation
    func setNavigationMode(_ mode: NavigationMode) {
        guard case .navigating = navigationState else { return }
        
        if mode == .haptic {
            initializeHapticEngineIfNeeded()
            hapticService.startNavigationBackgroundTask()
        } else {
            // Stop any ongoing haptic feedback when switching to visual
            hapticService.stopAllHaptics()
            hapticService.stopNavigationBackgroundTask()
        }
        
        navigationState = .navigating(mode: mode)
    }
    
    /// Update navigation progress based on current location
    func updateProgress(location: CLLocation) {
        // Always store the current location for route calculations
        currentLocation = location
        
        guard let route = currentRoute,
              case .navigating(let mode) = navigationState else {
            return
        }
        
        // Update route progress based on distance along polyline
        updateRouteProgress(location: location, route: route)
        
        // Check if we need to advance to next step
        let stepAdvanced = updateCurrentStep(for: location)
        
        // Trigger haptic feedback if in haptic mode
        if mode == .haptic {
            handleHapticFeedback(location: location, stepAdvanced: stepAdvanced)
        }
        
        // Check if we've arrived at destination
        checkForArrival(location: location)
    }
    
    /// Stop navigation and reset state
    func stopNavigation() {
        // Stop any ongoing haptic feedback and background tasks
        hapticService.stopAllHaptics()
        hapticService.stopNavigationBackgroundTask()
        
        // Reset navigation state
        currentRoute = nil
        currentStep = nil
        currentStepIndex = 0
        routeProgress = 0
        navigationState = .idle
        
        // Reset haptic state
        resetHapticState()
    }
    
    /// Select a specific route from available routes
    func selectRoute(_ route: MKRoute) {
        guard availableRoutes.contains(where: { $0 === route }) else { return }
        currentRoute = route
    }
    
    /// Clear route calculation error
    func clearError() {
        routeCalculationError = nil
    }
    
    /// Clear all routes and reset state
    func clearRoutes() {
        availableRoutes = []
        currentRoute = nil
        currentStep = nil
        currentStepIndex = 0
        routeProgress = 0
        routeCalculationError = nil
        if navigationState != .navigating(mode: .visual) && navigationState != .navigating(mode: .haptic) {
            navigationState = .idle
        }
    }
    
    /// Cancel ongoing route calculation
    func cancelRouteCalculation() {
        print("🗺️ NavigationEngine: Canceling route calculation")
        routeCalculationTask?.cancel()
        routeCalculationTask = nil
        if navigationState == .calculating {
            navigationState = .idle
            print("🗺️ NavigationEngine: State reset to idle after cancellation")
        }
        // Clear any calculation errors when manually canceling
        routeCalculationError = nil
    }
    
    // MARK: - Private Methods
    
    /// Update current navigation step based on location
    private func updateCurrentStep(for location: CLLocation) -> Bool {
        guard let route = currentRoute,
              currentStepIndex < route.steps.count else {
            return false
        }
        
        let currentStepLocation = CLLocation(
            latitude: route.steps[currentStepIndex].polyline.coordinate.latitude,
            longitude: route.steps[currentStepIndex].polyline.coordinate.longitude
        )
        
        let distanceToCurrentStep = location.distance(from: currentStepLocation)
        
        // If we're close to completing current step, advance to next
        if distanceToCurrentStep < stepProximityThreshold {
            advanceToNextStep()
            return true
        }
        
        return false
    }
    
    /// Advance to the next navigation step
    private func advanceToNextStep() {
        guard let route = currentRoute else { return }
        
        currentStepIndex += 1
        
        if currentStepIndex < route.steps.count {
            currentStep = route.steps[currentStepIndex]
        } else {
            // We've completed all steps
            currentStep = nil
        }
    }
    
    /// Update route progress based on current location
    private func updateRouteProgress(location: CLLocation, route: MKRoute) {
        // Calculate progress based on distance along the route polyline
        let totalDistance = route.distance
        
        // Estimate progress based on current step completion
        let stepsCompleted = Double(currentStepIndex)
        let totalSteps = Double(route.steps.count)
        
        if totalSteps > 0 {
            let stepProgress = stepsCompleted / totalSteps
            routeProgress = stepProgress * totalDistance
        }
    }
    
    /// Check if user has arrived at destination
    private func checkForArrival(location: CLLocation) {
        guard let route = currentRoute else { return }
        
        // Get the last step's coordinate as the destination
        let lastStep = route.steps.last
        let destinationCoordinate = lastStep?.polyline.coordinate ?? route.polyline.coordinate
        
        let destinationLocation = CLLocation(
            latitude: destinationCoordinate.latitude,
            longitude: destinationCoordinate.longitude
        )
        
        let distanceToDestination = location.distance(from: destinationLocation)
        
        // Consider arrived if within 20 meters of destination
        if distanceToDestination < 20 {
            // Trigger arrival haptic feedback if in haptic mode
            if case .navigating(let mode) = navigationState, mode == .haptic {
                triggerArrivalHaptic()
            }
            
            navigationState = .arrived
            currentStep = nil
        }
    }
    
    // MARK: - Haptic Feedback Methods
    
    /// Initialize haptic engine if needed and device is capable
    private func initializeHapticEngineIfNeeded() {
        guard hapticService.isHapticCapable else { return }
        
        do {
            try hapticService.initializeHapticEngine()
        } catch {
            print("Failed to initialize haptic engine: \(error)")
            // Graceful fallback - continue navigation without haptics
        }
    }
    
    /// Reset haptic feedback state
    private func resetHapticState() {
        lastHapticTriggerDistance = 0
        lastHapticTime = Date.distantPast
        hasTriggeredTurnHaptic = false
    }
    
    /// Handle haptic feedback based on navigation progress
    private func handleHapticFeedback(location: CLLocation, stepAdvanced: Bool) {
        guard let currentStep = currentStep else { return }
        
        // Calculate distance to current step
        let stepLocation = CLLocation(
            latitude: currentStep.polyline.coordinate.latitude,
            longitude: currentStep.polyline.coordinate.longitude
        )
        let distanceToStep = location.distance(from: stepLocation)
        
        // If we advanced to a new step, reset haptic state for this step
        if stepAdvanced {
            hasTriggeredTurnHaptic = false
        }
        
        // Check if we should trigger distance-based haptic cue
        if shouldTriggerDistanceBasedHaptic(distanceToStep: distanceToStep) {
            triggerNavigationHaptic(for: currentStep)
        }
    }
    
    /// Determine if haptic feedback should be triggered based on distance and timing
    private func shouldTriggerDistanceBasedHaptic(distanceToStep: CLLocationDistance) -> Bool {
        let now = Date()
        
        // Don't trigger if we've already triggered haptic for this step
        guard !hasTriggeredTurnHaptic else { return false }
        
        // Don't trigger if we're too far from the step
        guard distanceToStep <= hapticTriggerDistance else { return false }
        
        // Don't trigger if not enough time has passed since last haptic
        guard now.timeIntervalSince(lastHapticTime) >= hapticMinimumInterval else { return false }
        
        return true
    }
    
    /// Trigger appropriate haptic feedback based on step instruction
    private func triggerNavigationHaptic(for step: MKRoute.Step) {
        let instruction = step.instructions.lowercased()
        lastHapticTime = Date()
        hasTriggeredTurnHaptic = true
        
        Task {
            do {
                if instruction.contains("left") {
                    try await hapticService.playTurnLeftPattern()
                } else if instruction.contains("right") {
                    try await hapticService.playTurnRightPattern()
                } else if instruction.contains("straight") || instruction.contains("continue") {
                    try await hapticService.playContinueStraightPattern()
                } else {
                    // Default to continue straight for unknown instructions
                    try await hapticService.playContinueStraightPattern()
                }
            } catch {
                print("Failed to play haptic pattern: \(error)")
            }
        }
    }
    
    /// Trigger arrival haptic feedback
    private func triggerArrivalHaptic() {
        Task {
            do {
                try await hapticService.playArrivalPattern()
            } catch {
                print("Failed to play arrival haptic pattern: \(error)")
            }
        }
    }
}

// MARK: - Navigation Errors

enum NavigationError: LocalizedError {
    case noCurrentLocation
    case noRouteFound
    case routeCalculationFailed(Error)
    case routeCalculationTimeout
    case invalidDestination
    case networkError(Error)
    case serviceUnavailable
    case rateLimitExceeded
    case calculationCanceled
    
    var errorDescription: String? {
        switch self {
        case .noCurrentLocation:
            return "Current location is not available"
        case .noRouteFound:
            return "No route could be found to the destination"
        case .routeCalculationFailed(let error):
            return "Route calculation failed: \(error.localizedDescription)"
        case .routeCalculationTimeout:
            return "Route calculation timed out. Please try again."
        case .invalidDestination:
            return "Invalid destination provided"
        case .networkError(let error):
            return "Network error during route calculation: \(error.localizedDescription)"
        case .serviceUnavailable:
            return "Route calculation service is temporarily unavailable"
        case .rateLimitExceeded:
            return "Too many route requests. Please wait a moment and try again."
        case .calculationCanceled:
            return "Route calculation was canceled"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .routeCalculationTimeout, .serviceUnavailable:
            return true
        case .noCurrentLocation, .noRouteFound, .invalidDestination, .rateLimitExceeded, .calculationCanceled, .routeCalculationFailed:
            return false
        }
    }
    
    var retryDelay: TimeInterval {
        switch self {
        case .networkError:
            return 2.0
        case .routeCalculationTimeout:
            return 1.0
        case .serviceUnavailable:
            return 5.0
        default:
            return 0.0
        }
    }
}