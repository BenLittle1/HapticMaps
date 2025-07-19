import Foundation
import MapKit
import CoreLocation

/// Protocol defining search service functionality for location queries
protocol SearchServiceProtocol {
    /// Search for locations based on a text query
    /// - Parameter query: The search text
    /// - Returns: Array of SearchResult objects
    /// - Throws: SearchError for various failure scenarios
    func searchLocations(query: String) async throws -> [SearchResult]
    
    /// Reverse geocode a location to get place information
    /// - Parameter location: The location to reverse geocode
    /// - Returns: Array of CLPlacemark objects
    /// - Throws: SearchError for geocoding failures
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark]
}

/// Errors that can occur during search operations
enum SearchError: Error, LocalizedError {
    case emptyQuery
    case noResults
    case networkError(Error)
    case geocodingFailed(Error)
    case invalidLocation
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .noResults:
            return "No results found for your search"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .geocodingFailed(let error):
            return "Geocoding failed: \(error.localizedDescription)"
        case .invalidLocation:
            return "Invalid location provided"
        }
    }
}