import Foundation
import MapKit
import CoreLocation

/// Service for handling location search and geocoding operations with enhanced error recovery
class SearchService: SearchServiceProtocol {
    
    // MARK: - Properties
    
    private let geocoder = CLGeocoder()
    private var activeSearchTasks: Set<Task<Void, Never>> = []
    private let maxRetryAttempts = 3
    private let searchTimeout: TimeInterval = 30.0
    
    // MARK: - SearchServiceProtocol Implementation
    
    /// Search for locations based on a text query using MKLocalSearch with retry logic
    func searchLocations(query: String) async throws -> [SearchResult] {
        return try await performSearchWithRetry { [weak self] in
            try await self?.performLocationSearch(query: query) ?? []
        }
    }
    
    /// Reverse geocode a location to get place information with retry logic
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        return try await performGeocodingWithRetry { [weak self] in
            try await self?.performReverseGeocode(location: location) ?? []
        }
    }
    
    // MARK: - Private Implementation Methods
    
    private func performLocationSearch(query: String) async throws -> [SearchResult] {
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.emptyQuery
        }
        
        // Create search request
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Perform search with timeout
        return try await withThrowingTaskGroup(of: [SearchResult].self) { group in
            // Add the main search task
            group.addTask { [weak self] in
                guard let self = self else { throw SearchError.searchCanceled }
                return try await self.executeSearch(request: request)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.searchTimeout * 1_000_000_000))
                throw SearchError.searchTimeout
            }
            
            // Wait for first result (either success or timeout)
            guard let result = try await group.next() else {
                throw SearchError.serviceUnavailable
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func executeSearch(request: MKLocalSearch.Request) async throws -> [SearchResult] {
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
            // Analyze the underlying error to provide better error classification
            throw classifySearchError(error)
        }
    }
    
    private func performReverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
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
            throw classifyGeocodingError(error)
        }
    }
    
    // MARK: - Retry Logic
    
    private func performSearchWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: SearchError?
        
        for attempt in 1...maxRetryAttempts {
            do {
                return try await operation()
            } catch let error as SearchError {
                lastError = error
                
                // Don't retry non-retryable errors
                guard error.isRetryable && attempt < maxRetryAttempts else {
                    throw error
                }
                
                // Wait before retrying
                let delay = error.retryDelay * Double(attempt) // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                // Handle unexpected errors
                let searchError = SearchError.networkError(error)
                lastError = searchError
                
                guard attempt < maxRetryAttempts else {
                    throw searchError
                }
                
                try await Task.sleep(nanoseconds: UInt64(2.0 * Double(attempt) * 1_000_000_000))
            }
        }
        
        throw lastError ?? SearchError.serviceUnavailable
    }
    
    private func performGeocodingWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: SearchError?
        
        for attempt in 1...maxRetryAttempts {
            do {
                return try await operation()
            } catch let error as SearchError {
                lastError = error
                
                // Only retry network-related geocoding errors
                guard case .networkError = error, attempt < maxRetryAttempts else {
                    throw error
                }
                
                let delay = 2.0 * Double(attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                let searchError = SearchError.geocodingFailed(error)
                lastError = searchError
                
                guard attempt < maxRetryAttempts else {
                    throw searchError
                }
                
                try await Task.sleep(nanoseconds: UInt64(2.0 * Double(attempt) * 1_000_000_000))
            }
        }
        
        throw lastError ?? SearchError.serviceUnavailable
    }
    
    // MARK: - Error Classification
    
    private func classifySearchError(_ error: Error) -> SearchError {
        let nsError = error as NSError
        
        // Check for specific error codes that indicate different types of failures
        switch nsError.code {
        case NSURLErrorTimedOut, NSURLErrorCannotConnectToHost:
            return .searchTimeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkError(error)
        case NSURLErrorBadServerResponse, NSURLErrorCannotFindHost:
            return .serviceUnavailable
        case NSURLErrorResourceUnavailable:
            return .rateLimitExceeded
        default:
            // Check domain-specific errors
            if nsError.domain == MKErrorDomain {
                switch nsError.code {
                case Int(MKError.placemarkNotFound.rawValue):
                    return .noResults
                case Int(MKError.loadingThrottled.rawValue):
                    return .rateLimitExceeded
                case Int(MKError.serverFailure.rawValue):
                    return .serviceUnavailable
                default:
                    return .serviceUnavailable
                }
            }
            
            return .networkError(error)
        }
    }
    
    private func classifyGeocodingError(_ error: Error) -> SearchError {
        let nsError = error as NSError
        
        if nsError.domain == kCLErrorDomain {
            switch nsError.code {
            case CLError.network.rawValue:
                return .networkError(error)
            case CLError.geocodeCanceled.rawValue:
                return .searchCanceled
            case CLError.geocodeFoundNoResult.rawValue:
                return .noResults
            case CLError.geocodeFoundPartialResult.rawValue:
                return .noResults
            default:
                return .geocodingFailed(error)
            }
        }
        
        return .geocodingFailed(error)
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
    /// Search for locations with a region bias for more relevant results and retry logic
    func searchLocations(query: String, in region: MKCoordinateRegion) async throws -> [SearchResult] {
        return try await performSearchWithRetry { [weak self] in
            try await self?.performLocationSearchInRegion(query: query, region: region) ?? []
        }
    }
    
    private func performLocationSearchInRegion(query: String, region: MKCoordinateRegion) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.emptyQuery
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        return try await executeSearch(request: request)
    }
}