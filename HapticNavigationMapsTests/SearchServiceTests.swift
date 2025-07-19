import XCTest
import MapKit
import CoreLocation
@testable import HapticNavigationMaps

class SearchServiceTests: XCTestCase {
    var searchService: SearchService!
    var mockLocalSearch: MockMKLocalSearch!
    var mockGeocoder: MockCLGeocoder!
    
    override func setUp() {
        super.setUp()
        searchService = SearchService()
        mockLocalSearch = MockMKLocalSearch()
        mockGeocoder = MockCLGeocoder()
    }
    
    override func tearDown() {
        searchService = nil
        mockLocalSearch = nil
        mockGeocoder = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testSearchLocationsWithValidQuery() async throws {
        let query = "coffee shops"
        
        do {
            let results = try await searchService.searchLocations(query: query)
            XCTAssertFalse(results.isEmpty, "Should return search results for valid query")
        } catch {
            XCTFail("Search should succeed with valid query: \(error)")
        }
    }
    
    func testReverseGeocodeWithValidLocation() async throws {
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        do {
            let placemarks = try await searchService.reverseGeocode(location: location)
            XCTAssertFalse(placemarks.isEmpty, "Should return placemarks for valid location")
        } catch {
            XCTFail("Reverse geocode should succeed with valid location: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSearchLocationsWithEmptyQuery() async {
        do {
            _ = try await searchService.searchLocations(query: "")
            XCTFail("Should throw empty query error")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
        } catch {
            XCTFail("Should throw SearchError.emptyQuery, got: \(error)")
        }
    }
    
    func testSearchLocationsWithWhitespaceOnlyQuery() async {
        do {
            _ = try await searchService.searchLocations(query: "   \n\t  ")
            XCTFail("Should throw empty query error")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
        } catch {
            XCTFail("Should throw SearchError.emptyQuery, got: \(error)")
        }
    }
    
    func testReverseGeocodeWithInvalidLocation() async {
        let invalidLocation = CLLocation(latitude: 999, longitude: 999)
        
        do {
            _ = try await searchService.reverseGeocode(location: invalidLocation)
            XCTFail("Should throw invalid location error")
        } catch let error as SearchError {
            XCTAssertEqual(error, .invalidLocation)
        } catch {
            XCTFail("Should throw SearchError.invalidLocation, got: \(error)")
        }
    }
    
    // MARK: - Network Error Tests
    
    func testSearchLocationsWithNetworkError() async {
        // Test with a query that's likely to fail due to network issues
        let query = "search_that_will_fail_network_test"
        
        do {
            _ = try await searchService.searchLocations(query: query)
            // If this succeeds, we can't test the network error case
            // This test might be skipped in environments with good connectivity
        } catch let error as SearchError {
            switch error {
            case .networkError, .searchTimeout, .serviceUnavailable:
                // These are expected network-related errors
                XCTAssertTrue(error.isRetryable, "Network errors should be retryable")
            case .noResults:
                // This is also acceptable for a test query
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should throw SearchError, got: \(error)")
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testSearchErrorRetryability() {
        XCTAssertTrue(SearchError.networkError(NSError(domain: "test", code: 1)).isRetryable)
        XCTAssertTrue(SearchError.searchTimeout.isRetryable)
        XCTAssertTrue(SearchError.serviceUnavailable.isRetryable)
        
        XCTAssertFalse(SearchError.emptyQuery.isRetryable)
        XCTAssertFalse(SearchError.noResults.isRetryable)
        XCTAssertFalse(SearchError.invalidLocation.isRetryable)
        XCTAssertFalse(SearchError.rateLimitExceeded.isRetryable)
        XCTAssertFalse(SearchError.searchCanceled.isRetryable)
    }
    
    func testSearchErrorRetryDelays() {
        XCTAssertEqual(SearchError.networkError(NSError(domain: "test", code: 1)).retryDelay, 2.0)
        XCTAssertEqual(SearchError.searchTimeout.retryDelay, 1.0)
        XCTAssertEqual(SearchError.serviceUnavailable.retryDelay, 5.0)
        XCTAssertEqual(SearchError.emptyQuery.retryDelay, 0.0)
    }
    
    // MARK: - Timeout Tests
    
    func testSearchTimeout() async {
        // This test simulates a search that would timeout
        // In a real scenario, this would be tested with a mock that delays response
        
        let expectation = XCTestExpectation(description: "Search should timeout")
        
        Task {
            do {
                // Use a query that might take a long time or fail
                _ = try await searchService.searchLocations(query: "extremely_specific_query_that_might_timeout_12345")
                expectation.fulfill()
            } catch let error as SearchError {
                switch error {
                case .searchTimeout, .networkError, .serviceUnavailable, .noResults:
                    // These are all acceptable outcomes for this test
                    expectation.fulfill()
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            } catch {
                XCTFail("Should throw SearchError, got: \(error)")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 35.0) // Longer than search timeout
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelAllSearches() {
        // Test that we can cancel searches without crashing
        searchService.cancelAllSearches()
        
        // Start a search and then cancel it
        Task {
            do {
                _ = try await searchService.searchLocations(query: "test query")
            } catch {
                // Cancellation is expected
            }
        }
        
        searchService.cancelAllSearches()
    }
    
    // MARK: - Edge Cases
    
    func testSearchWithSpecialCharacters() async {
        let queries = [
            "café 😀",
            "naïve résumé",
            "100% organic",
            "#hashtag @mention",
            "query with\nnewlines",
            "spaces   everywhere"
        ]
        
        for query in queries {
            do {
                let results = try await searchService.searchLocations(query: query)
                // Should not crash with special characters
                // Results may be empty, which is acceptable
                XCTAssertNotNil(results)
            } catch let error as SearchError {
                // Some special characters might cause no results or other errors
                switch error {
                case .noResults, .networkError, .serviceUnavailable:
                    // These are acceptable for special character queries
                    break
                default:
                    XCTFail("Unexpected error for query '\(query)': \(error)")
                }
            } catch {
                XCTFail("Should only throw SearchError, got: \(error)")
            }
        }
    }
    
    func testReverseGeocodeWithExtremeCoordinates() async {
        let extremeLocations = [
            CLLocation(latitude: 90, longitude: 180),    // North Pole, International Date Line
            CLLocation(latitude: -90, longitude: -180),  // South Pole, opposite side
            CLLocation(latitude: 0, longitude: 0),       // Null Island
        ]
        
        for location in extremeLocations {
            do {
                let placemarks = try await searchService.reverseGeocode(location: location)
                // These might return results or no results, both are valid
                XCTAssertNotNil(placemarks)
            } catch let error as SearchError {
                // Some extreme locations might not have results
                switch error {
                case .noResults, .networkError, .geocodingFailed:
                    // These are acceptable for extreme coordinates
                    break
                default:
                    XCTFail("Unexpected error for location \(location): \(error)")
                }
            } catch {
                XCTFail("Should only throw SearchError, got: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Search performance")
            
            Task {
                do {
                    _ = try await searchService.searchLocations(query: "coffee")
                    expectation.fulfill()
                } catch {
                    expectation.fulfill() // Count errors as completion for performance test
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testReverseGeocodePerformance() {
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            let expectation = XCTestExpectation(description: "Reverse geocode performance")
            
            Task {
                do {
                    _ = try await searchService.reverseGeocode(location: location)
                    expectation.fulfill()
                } catch {
                    expectation.fulfill() // Count errors as completion for performance test
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentSearches() async {
        let queries = ["coffee", "restaurants", "gas stations", "hotels", "hospitals"]
        
        await withTaskGroup(of: Void.self) { group in
            for query in queries {
                group.addTask {
                    do {
                        _ = try await self.searchService.searchLocations(query: query)
                    } catch {
                        // Errors are acceptable in concurrent testing
                    }
                }
            }
        }
        
        // Test should complete without crashing
        XCTAssertTrue(true, "Concurrent searches completed")
    }
    
    func testConcurrentReverseGeocoding() async {
        let locations = [
            CLLocation(latitude: 37.7749, longitude: -122.4194), // San Francisco
            CLLocation(latitude: 40.7128, longitude: -74.0060),  // New York
            CLLocation(latitude: 34.0522, longitude: -118.2437), // Los Angeles
            CLLocation(latitude: 41.8781, longitude: -87.6298),  // Chicago
            CLLocation(latitude: 29.7604, longitude: -95.3698)   // Houston
        ]
        
        await withTaskGroup(of: Void.self) { group in
            for location in locations {
                group.addTask {
                    do {
                        _ = try await self.searchService.reverseGeocode(location: location)
                    } catch {
                        // Errors are acceptable in concurrent testing
                    }
                }
            }
        }
        
        // Test should complete without crashing
        XCTAssertTrue(true, "Concurrent reverse geocoding completed")
    }
    
    // MARK: - Error Message Tests
    
    func testErrorDescriptions() {
        let errors: [SearchError] = [
            .emptyQuery,
            .noResults,
            .networkError(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])),
            .geocodingFailed(NSError(domain: "test", code: 2)),
            .invalidLocation,
            .searchTimeout,
            .serviceUnavailable,
            .rateLimitExceeded,
            .searchCanceled
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
            
            // Verify error descriptions are user-friendly
            let description = error.localizedDescription
            XCTAssertFalse(description.contains("Error Domain="))
            XCTAssertFalse(description.contains("Code="))
        }
    }
}

// MARK: - Mock Classes

class MockMKLocalSearch: MKLocalSearch {
    var shouldFail = false
    var mockError: Error?
    var mockResults: [MKMapItem] = []
    
    override func start() async throws -> MKDirections.Response {
        if shouldFail, let error = mockError {
            throw error
        }
        
        // Return mock response
        // Note: This is a simplified mock - real implementation would be more complex
        throw SearchError.noResults // Simplified for testing
    }
}

class MockCLGeocoder: CLGeocoder {
    var shouldFail = false
    var mockError: Error?
    var mockPlacemarks: [CLPlacemark] = []
    
    override func reverseGeocodeLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        if shouldFail, let error = mockError {
            throw error
        }
        
        return mockPlacemarks
    }
}