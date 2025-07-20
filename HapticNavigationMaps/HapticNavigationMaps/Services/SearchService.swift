import Foundation
import MapKit
import CoreLocation

/// Optimized service for handling location search operations with fast response times
class SearchService: SearchServiceProtocol {
    
    // MARK: - Properties
    
    private let geocoder = CLGeocoder()
    private var activeSearchTasks: Set<Task<Void, Never>> = []
    
    // Optimized for speed - shorter timeout and no heavy retry logic
    private let searchTimeout: TimeInterval = 8.0 // Reduced from 30s
    private let maxRetryAttempts = 2 // Reduced from 3
    
    // MARK: - SearchServiceProtocol Implementation
    
    /// Search for locations based on a text query - optimized for speed
    func searchLocations(query: String) async throws -> [SearchResult] {
        // Validate input quickly
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw SearchError.emptyQuery
        }
        
        // Perform search with reduced timeout for faster response
        return try await performLocationSearch(query: trimmedQuery)
    }
    
    /// Reverse geocode a location to get place information
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            throw SearchError.invalidLocation
        }
        
        return try await performReverseGeocode(location: location)
    }
    
    // MARK: - Optimized Implementation Methods
    
    private func performLocationSearch(query: String) async throws -> [SearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Set result types for faster searches
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        return try await withThrowingTaskGroup(of: [SearchResult].self) { group in
            // Add the main search task
            group.addTask {
                return try await self.executeSearchFast(request: request)
            }
            
            // Add timeout task with reduced timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.searchTimeout * 1_000_000_000))
                throw SearchError.searchTimeout
            }
            
            // Return first result (either success or timeout)
            guard let result = try await group.next() else {
                throw SearchError.serviceUnavailable
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func executeSearchFast(request: MKLocalSearch.Request) async throws -> [SearchResult] {
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            guard !response.mapItems.isEmpty else {
                throw SearchError.noResults
            }
            
            // Transform results quickly
            let searchResults = response.mapItems.compactMap { mapItem in
                SearchResult(mapItem: mapItem)
            }
            
            return searchResults
            
        } catch {
            // Simplified error handling for speed
            if let error = error as? SearchError {
                throw error
            } else {
                throw SearchError.networkError(error)
            }
        }
    }
    
    private func performReverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard !placemarks.isEmpty else {
                throw SearchError.noResults
            }
            
            return placemarks
            
        } catch {
            if let clError = error as? CLError {
                switch clError.code {
                case .network:
                    throw SearchError.networkError(error)
                case .geocodeCanceled:
                    throw SearchError.searchCanceled
                case .geocodeFoundNoResult:
                    throw SearchError.noResults
                default:
                    throw SearchError.geocodingFailed(error)
                }
            }
            throw SearchError.geocodingFailed(error)
        }
    }
    
    // MARK: - Task Management
    
    func cancelAllSearches() {
        geocoder.cancelGeocode()
        
        for task in activeSearchTasks {
            task.cancel()
        }
        activeSearchTasks.removeAll()
    }
    
    deinit {
        cancelAllSearches()
    }
}

// MARK: - Extensions

extension SearchService {
    /// Search for locations with a region bias for more relevant results
    func searchLocations(query: String, in region: MKCoordinateRegion) async throws -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw SearchError.emptyQuery
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.region = region
        
        // Set result types for faster searches
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        return try await executeSearchFast(request: request)
    }
    
    /// Quick search for common categories
    func searchCategory(_ category: String, in region: MKCoordinateRegion? = nil) async throws -> [SearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category
        
        if let region = region {
            request.region = region
        }
        
        // Optimize for category searches
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest]
        }
        
        return try await executeSearchFast(request: request)
    }
}