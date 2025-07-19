import Foundation
import MapKit
import CoreLocation

/// Service for handling location search and geocoding operations
class SearchService: SearchServiceProtocol {
    
    // MARK: - Properties
    
    private let geocoder = CLGeocoder()
    
    // MARK: - SearchServiceProtocol Implementation
    
    /// Search for locations based on a text query using MKLocalSearch
    func searchLocations(query: String) async throws -> [SearchResult] {
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.emptyQuery
        }
        
        // Create search request
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Perform search
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            // Check if we have results
            guard !response.mapItems.isEmpty else {
                throw SearchError.noResults
            }
            
            // Transform MKMapItem to SearchResult
            let searchResults = response.mapItems.map { mapItem in
                SearchResult(mapItem: mapItem)
            }
            
            return searchResults
            
        } catch let error as SearchError {
            // Re-throw our custom errors
            throw error
        } catch {
            // Wrap other errors as network errors
            throw SearchError.networkError(error)
        }
    }
    
    /// Reverse geocode a location to get place information
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        // Validate location
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            throw SearchError.invalidLocation
        }
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard !placemarks.isEmpty else {
                throw SearchError.noResults
            }
            
            return placemarks
            
        } catch {
            throw SearchError.geocodingFailed(error)
        }
    }
}

// MARK: - Extensions

extension SearchService {
    /// Search for locations with a region bias for more relevant results
    func searchLocations(query: String, in region: MKCoordinateRegion) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.emptyQuery
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            guard !response.mapItems.isEmpty else {
                throw SearchError.noResults
            }
            
            let searchResults = response.mapItems.map { mapItem in
                SearchResult(mapItem: mapItem)
            }
            
            return searchResults
            
        } catch let error as SearchError {
            throw error
        } catch {
            throw SearchError.networkError(error)
        }
    }
}