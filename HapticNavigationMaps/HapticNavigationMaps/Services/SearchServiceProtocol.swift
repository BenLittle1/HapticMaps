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
    
    /// Cancel all active search operations
    func cancelAllSearches()
}

/// Enhanced errors that can occur during search operations
enum SearchError: Error, LocalizedError, Equatable {
    case emptyQuery
    case noResults
    case networkError(Error)
    case geocodingFailed(Error)
    case invalidLocation
    case searchTimeout
    case serviceUnavailable
    case rateLimitExceeded
    case searchCanceled
    
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
        case .searchTimeout:
            return "Search request timed out. Please try again."
        case .serviceUnavailable:
            return "Search service is temporarily unavailable. Please try again later."
        case .rateLimitExceeded:
            return "Too many search requests. Please wait a moment and try again."
        case .searchCanceled:
            return "Search was canceled"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .searchTimeout, .serviceUnavailable:
            return true
        case .emptyQuery, .noResults, .invalidLocation, .geocodingFailed, .rateLimitExceeded, .searchCanceled:
            return false
        }
    }
    
    var retryDelay: TimeInterval {
        switch self {
        case .networkError:
            return 2.0
        case .searchTimeout:
            return 1.0
        case .serviceUnavailable:
            return 5.0
        default:
            return 0.0
        }
    }
    
    static func == (lhs: SearchError, rhs: SearchError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyQuery, .emptyQuery),
             (.noResults, .noResults),
             (.invalidLocation, .invalidLocation),
             (.searchTimeout, .searchTimeout),
             (.serviceUnavailable, .serviceUnavailable),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.searchCanceled, .searchCanceled):
            return true
        case (.networkError, .networkError),
             (.geocodingFailed, .geocodingFailed):
            return true // Consider all instances of these equal for comparison
        default:
            return false
        }
    }
}