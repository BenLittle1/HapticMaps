import Foundation
import MapKit
import CoreLocation
import Combine

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
    private var routeCalculationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - NavigationEngineProtocol Implementation
    
    /// Calculate route to destination using MKDirections
    func calculateRoute(to destination: MKMapItem) async throws -> MKRoute {
        // Cancel any existing route calculation
        cancelRouteCalculation()
        
        // Clear any previous errors
        routeCalculationError = nil
        
        // Set calculating state
        navigationState = .calculating
        
        // Ensure we have a current location
        guard let currentLocation = currentLocation else {
            navigationState = .idle
            let error = NavigationError.noCurrentLocation
            routeCalculationError = error
            throw error
        }
        
        do {
            // Create route calculation with timeout
            let route = try await withThrowingTaskGroup(of: MKDirections.Response.self) { group in
                // Add the main route calculation task
                group.addTask {
                    let request = MKDirections.Request()
                    request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
                    request.destination = destination
                    request.transportType = .walking
                    request.requestsAlternateRoutes = true
                    
                    let directions = MKDirections(request: request)
                    return try await directions.calculate()
                }
                
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    throw NavigationError.routeCalculationTimeout
                }
                
                // Wait for first result (either success or timeout)
                guard let response = try await group.next() else {
                    throw NavigationError.routeCalculationFailed(NSError(domain: "NavigationEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response received"]))
                }
                
                group.cancelAll()
                return response
            }
            
            guard !route.routes.isEmpty else {
                navigationState = .idle
                let error = NavigationError.noRouteFound
                routeCalculationError = error
                throw error
            }
            
            // Store all available routes
            availableRoutes = route.routes
            currentRoute = route.routes.first
            navigationState = .idle
            
            return route.routes.first!
            
        } catch {
            // Always reset state on error
            navigationState = .idle
            let navError = error as? NavigationError ?? NavigationError.routeCalculationFailed(error)
            routeCalculationError = navError
            throw navError
        }
    }
    
    /// Start navigation with the provided route
    func startNavigation(route: MKRoute) {
        currentRoute = route
        currentStepIndex = 0
        routeProgress = 0
        
        // Set initial step
        if !route.steps.isEmpty {
            currentStep = route.steps[0]
        }
        
        navigationState = .navigating(mode: .visual)
    }
    
    /// Update navigation progress based on current location
    func updateProgress(location: CLLocation) {
        // Always store the current location for route calculations
        currentLocation = location
        
        guard let route = currentRoute,
              case .navigating = navigationState else {
            return
        }
        
        // Update route progress based on distance along polyline
        updateRouteProgress(location: location, route: route)
        
        // Check if we need to advance to next step
        updateCurrentStep(for: location)
        
        // Check if we've arrived at destination
        checkForArrival(location: location)
    }
    
    /// Stop navigation and reset state
    func stopNavigation() {
        currentRoute = nil
        currentStep = nil
        currentStepIndex = 0
        routeProgress = 0
        navigationState = .idle
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
        routeCalculationTask?.cancel()
        routeCalculationTask = nil
        if navigationState == .calculating {
            navigationState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    /// Update current navigation step based on location
    private func updateCurrentStep(for location: CLLocation) {
        guard let route = currentRoute,
              currentStepIndex < route.steps.count else {
            return
        }
        
        let currentStepLocation = CLLocation(
            latitude: route.steps[currentStepIndex].polyline.coordinate.latitude,
            longitude: route.steps[currentStepIndex].polyline.coordinate.longitude
        )
        
        let distanceToCurrentStep = location.distance(from: currentStepLocation)
        
        // If we're close to completing current step, advance to next
        if distanceToCurrentStep < stepProximityThreshold {
            advanceToNextStep()
        }
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
            navigationState = .arrived
            currentStep = nil
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
        }
    }
}