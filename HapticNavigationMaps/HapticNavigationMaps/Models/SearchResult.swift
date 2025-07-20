import Foundation
import MapKit
import CoreLocation

/// Represents a search result from location queries
struct SearchResult: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let formattedAddress: String
    
    // Store essential placemark data for reconstruction
    private let placemarkData: PlacemarkData
    
    init(mapItem: MKMapItem) {
        self.id = UUID()
        self.title = mapItem.name ?? "Unknown Location"
        self.subtitle = mapItem.placemark.title ?? ""
        self.coordinate = mapItem.placemark.coordinate
        
        // Generate formatted address
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
        
        self.formattedAddress = addressComponents.joined(separator: ", ")
        
        // Store placemark data for reconstruction
        self.placemarkData = PlacemarkData(
            name: mapItem.name,
            thoroughfare: placemark.thoroughfare,
            subThoroughfare: placemark.subThoroughfare,
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            administrativeArea: placemark.administrativeArea,
            subAdministrativeArea: placemark.subAdministrativeArea,
            postalCode: placemark.postalCode,
            country: placemark.country,
            isoCountryCode: placemark.isoCountryCode
        )
    }
    
    /// Reconstructed MKMapItem for use with MapKit
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(
            coordinate: coordinate,
            addressDictionary: placemarkData.addressDictionary
        )
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        return mapItem
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

// MARK: - Supporting Types

private struct PlacemarkData: Codable {
    let name: String?
    let thoroughfare: String?
    let subThoroughfare: String?
    let locality: String?
    let subLocality: String?
    let administrativeArea: String?
    let subAdministrativeArea: String?
    let postalCode: String?
    let country: String?
    let isoCountryCode: String?
    
    var addressDictionary: [String: Any] {
        var dict: [String: Any] = [:]
        
        if let name = name { dict["Name"] = name }
        if let thoroughfare = thoroughfare { dict["Thoroughfare"] = thoroughfare }
        if let subThoroughfare = subThoroughfare { dict["SubThoroughfare"] = subThoroughfare }
        if let locality = locality { dict["City"] = locality }
        if let subLocality = subLocality { dict["SubLocality"] = subLocality }
        if let administrativeArea = administrativeArea { dict["State"] = administrativeArea }
        if let subAdministrativeArea = subAdministrativeArea { dict["SubAdministrativeArea"] = subAdministrativeArea }
        if let postalCode = postalCode { dict["ZIP"] = postalCode }
        if let country = country { dict["Country"] = country }
        if let isoCountryCode = isoCountryCode { dict["CountryCode"] = isoCountryCode }
        
        return dict
    }
}

// MARK: - Coordinate Codable Support

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: lat, longitude: lng)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension SearchResult {
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a location that was tapped on the map
struct TappedLocation: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.timestamp = Date()
    }
    
    /// Convert to MKMapItem for route calculation
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Dropped Pin"
        return mapItem
    }
    
    /// Get display name for the location
    var displayName: String {
        return "Dropped Pin"
    }
    
    static func == (lhs: TappedLocation, rhs: TappedLocation) -> Bool {
        return lhs.id == rhs.id
    }
}