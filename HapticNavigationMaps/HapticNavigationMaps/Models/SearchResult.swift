import Foundation
import MapKit
import CoreLocation

/// Represents a search result from location queries
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let mapItem: MKMapItem
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        self.title = mapItem.name ?? "Unknown Location"
        self.subtitle = mapItem.placemark.title ?? ""
        self.coordinate = mapItem.placemark.coordinate
    }
    
    /// Formatted address for display
    var formattedAddress: String {
        let placemark = mapItem.placemark
        var addressComponents: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    /// Distance from a given location
    func distance(from location: CLLocation) -> CLLocationDistance {
        let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: searchLocation)
    }
    
    /// Formatted distance string
    func formattedDistance(from location: CLLocation) -> String {
        let distance = distance(from: location)
        let formatter = MKDistanceFormatter()
        return formatter.string(fromDistance: distance)
    }
}

extension SearchResult {
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}