import Foundation
import CoreLocation
import MapKit

/// Represents a single step in a navigation route
struct RouteStep: Identifiable, Equatable {
    let id = UUID()
    let instruction: String
    let distance: CLLocationDistance
    let maneuverType: MKDirectionsTransportType
    let coordinate: CLLocationCoordinate2D
    
    /// Distance formatted for display
    var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        return formatter.string(fromDistance: distance)
    }
    
    /// Human-readable maneuver description
    var maneuverDescription: String {
        switch maneuverType {
        case .automobile:
            return "Drive"
        case .walking:
            return "Walk"
        default:
            return "Continue"
        }
    }
}

extension RouteStep {
    static func == (lhs: RouteStep, rhs: RouteStep) -> Bool {
        return lhs.id == rhs.id
    }
}