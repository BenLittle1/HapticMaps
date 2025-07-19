import Foundation
import MapKit
import CoreLocation
import Combine

/// ViewModel for managing navigation state and turn-by-turn instructions
@MainActor
class NavigationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentStep: MKRoute.Step?
    @Published private(set) var nextStep: MKRoute.Step?
    @Published private(set) var distanceToNextManeuver: CLLocationDistance = 0
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var totalSteps: Int = 0
    @Published private(set) var routeProgress: Double = 0.0 // 0.0 to 1.0
    @Published private(set) var isAdvanceNotificationActive: Bool = false
    
    // MARK: - Private Properties
    private let navigationEngine: any NavigationEngineProtocol
    private let advanceNotificationDistance: CLLocationDistance = 100 // meters
    private let stepCompletionThreshold: CLLocationDistance = 30 // meters
    private var cancellables = Set<AnyCancellable>()
    private var currentRoute: MKRoute?
    private var lastKnownLocation: CLLocation?
    
    // MARK: - Initialization
    init(navigationEngine: any NavigationEngineProtocol) {
        self.navigationEngine = navigationEngine
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Update navigation progress with current location
    func updateProgress(location: CLLocation) {
        lastKnownLocation = location
        
        guard let route = currentRoute,
              case .navigating = navigationEngine.navigationState else {
            return
        }
        
        // Update distance to next maneuver
        updateDistanceToNextManeuver(location: location)
        
        // Check if we should advance to next step
        checkStepAdvancement(location: location)
        
        // Update overall route progress
        updateRouteProgress(location: location, route: route)
        
        // Check for advance turn notifications
        checkAdvanceNotification()
    }
    
    /// Toggle navigation mode between visual and haptic
    func toggleNavigationMode() {
        guard case .navigating(let currentMode) = navigationEngine.navigationState else {
            return
        }
        
        let _ = currentMode == .visual ? NavigationMode.haptic : NavigationMode.visual
        
        // Update navigation state with new mode
        // Note: This would typically be handled by the NavigationEngine
        // For now, we'll trigger a state change through the engine
        if let route = currentRoute {
            navigationEngine.stopNavigation()
            navigationEngine.startNavigation(route: route)
            // The actual mode switching logic would be implemented in NavigationEngine
        }
    }
    
    /// Stop navigation and reset state
    func stopNavigation() {
        navigationEngine.stopNavigation()
        resetNavigationState()
    }
    
    /// Get formatted instruction for current step
    func getCurrentInstruction() -> String {
        guard let step = currentStep else {
            return "Continue on route"
        }
        
        return step.instructions.isEmpty ? "Continue straight" : step.instructions
    }
    
    /// Get formatted distance to next maneuver
    func getFormattedDistanceToManeuver() -> String {
        if distanceToNextManeuver < 100 {
            return String(format: "In %.0f m", distanceToNextManeuver)
        } else if distanceToNextManeuver < 1000 {
            return String(format: "In %.0f m", distanceToNextManeuver)
        } else {
            return String(format: "In %.1f km", distanceToNextManeuver / 1000)
        }
    }
    
    /// Check if arrival detection should be triggered
    func checkArrival(location: CLLocation) -> Bool {
        guard let route = currentRoute else { return false }
        
        // Get destination coordinate from the last step or route endpoint
        let destinationCoordinate: CLLocationCoordinate2D
        if let lastStep = route.steps.last {
            destinationCoordinate = lastStep.polyline.coordinate
        } else {
            destinationCoordinate = route.polyline.coordinate
        }
        
        let destinationLocation = CLLocation(
            latitude: destinationCoordinate.latitude,
            longitude: destinationCoordinate.longitude
        )
        
        let distanceToDestination = location.distance(from: destinationLocation)
        
        // Consider arrived if within 20 meters of destination
        return distanceToDestination <= 20
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Note: We'll handle navigation state changes through direct method calls
        // from the MapView when navigation state changes occur
    }
    
    private func handleNavigationStateChange() {
        switch navigationEngine.navigationState {
        case .navigating:
            if let route = navigationEngine.currentRoute {
                setupNavigationForRoute(route)
            }
        case .arrived:
            handleArrival()
        case .idle, .calculating:
            resetNavigationState()
        }
    }
    
    private func setupNavigationForRoute(_ route: MKRoute) {
        currentRoute = route
        totalSteps = route.steps.count
        currentStepIndex = 0
        routeProgress = 0.0
        
        // Set initial step
        if !route.steps.isEmpty {
            currentStep = route.steps[0]
            
            // Set next step if available
            if route.steps.count > 1 {
                nextStep = route.steps[1]
            }
        }
        
        // Initialize distance calculation if we have a location
        if let location = lastKnownLocation {
            updateDistanceToNextManeuver(location: location)
        }
    }
    
    private func updateDistanceToNextManeuver(location: CLLocation) {
        guard let step = currentStep else {
            distanceToNextManeuver = 0
            return
        }
        
        let stepLocation = CLLocation(
            latitude: step.polyline.coordinate.latitude,
            longitude: step.polyline.coordinate.longitude
        )
        
        distanceToNextManeuver = location.distance(from: stepLocation)
    }
    
    private func checkStepAdvancement(location: CLLocation) {
        guard let route = currentRoute,
              currentStepIndex < route.steps.count else {
            return
        }
        
        // Check if we're close enough to the current step to advance
        if distanceToNextManeuver <= stepCompletionThreshold {
            advanceToNextStep(route: route)
        }
    }
    
    private func advanceToNextStep(route: MKRoute) {
        currentStepIndex += 1
        
        if currentStepIndex < route.steps.count {
            // Move to next step
            currentStep = route.steps[currentStepIndex]
            
            // Set next step preview
            if currentStepIndex + 1 < route.steps.count {
                nextStep = route.steps[currentStepIndex + 1]
            } else {
                nextStep = nil
            }
        } else {
            // We've completed all steps
            currentStep = nil
            nextStep = nil
        }
        
        // Reset advance notification
        isAdvanceNotificationActive = false
    }
    
    private func updateRouteProgress(location: CLLocation, route: MKRoute) {
        // Calculate progress based on distance traveled vs total route distance
        let _ = route.distance
        
        // Estimate distance traveled based on current step progress
        let stepsCompleted = Double(currentStepIndex)
        let totalStepsCount = Double(route.steps.count)
        
        if totalStepsCount > 0 {
            routeProgress = stepsCompleted / totalStepsCount
        } else {
            routeProgress = 0.0
        }
        
        // Ensure progress doesn't exceed 1.0
        routeProgress = min(routeProgress, 1.0)
    }
    
    private func checkAdvanceNotification() {
        // Activate advance notification when approaching a turn
        let shouldShowAdvanceNotification = distanceToNextManeuver <= advanceNotificationDistance &&
                                          distanceToNextManeuver > stepCompletionThreshold &&
                                          currentStep != nil
        
        if shouldShowAdvanceNotification != isAdvanceNotificationActive {
            isAdvanceNotificationActive = shouldShowAdvanceNotification
        }
    }
    
    private func handleArrival() {
        currentStep = nil
        nextStep = nil
        routeProgress = 1.0
        isAdvanceNotificationActive = false
    }
    
    private func resetNavigationState() {
        currentStep = nil
        nextStep = nil
        distanceToNextManeuver = 0
        currentStepIndex = 0
        totalSteps = 0
        routeProgress = 0.0
        isAdvanceNotificationActive = false
        currentRoute = nil
    }
}

// MARK: - Navigation Progress Extensions

extension NavigationViewModel {
    /// Get progress percentage as string
    var progressPercentage: String {
        return String(format: "%.0f%%", routeProgress * 100)
    }
    
    /// Get current step number for display
    var currentStepNumber: Int {
        return currentStepIndex + 1
    }
    
    /// Check if there are more steps ahead
    var hasMoreSteps: Bool {
        return nextStep != nil
    }
    
    /// Get estimated time to next maneuver based on walking speed
    var estimatedTimeToManeuver: TimeInterval {
        // Assume average walking speed of 1.4 m/s (5 km/h)
        let walkingSpeed: CLLocationDistance = 1.4
        return distanceToNextManeuver / walkingSpeed
    }
    
    /// Get formatted time to next maneuver
    var formattedTimeToManeuver: String {
        let time = estimatedTimeToManeuver
        
        if time < 60 {
            return String(format: "%.0f sec", time)
        } else {
            return String(format: "%.0f min", time / 60)
        }
    }
}