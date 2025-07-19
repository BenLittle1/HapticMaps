import Foundation
import MapKit
import CoreLocation

/// Protocol defining the navigation engine interface
@MainActor
protocol NavigationEngineProtocol: ObservableObject {
    var currentRoute: MKRoute? { get }
    var currentStep: MKRoute.Step? { get }
    var navigationState: NavigationState { get }
    var availableRoutes: [MKRoute] { get }
    var routeCalculationError: NavigationError? { get }
    
    func calculateRoute(to destination: MKMapItem) async throws -> MKRoute
    func startNavigation(route: MKRoute)
    func updateProgress(location: CLLocation)
    func stopNavigation()
    func selectRoute(_ route: MKRoute)
    func clearError()
    func clearRoutes()
    func cancelRouteCalculation()
}