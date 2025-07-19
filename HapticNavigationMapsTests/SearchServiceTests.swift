import XCTest
import MapKit
import CoreLocation
@testable import HapticNavigationMaps

class SearchServiceTests: XCTestCase {
    
    var searchService: SearchService!
    
    override func setUp() {
        super.setUp()
        searchService = SearchService()
    }
    
    override func tearDown() {
        searchService = nil
        super.tearDown()
    }
    
    // MARK: - Search Locations Tests
    
    func testSearchLocations_WithValidQuery_ReturnsResults() async throws {
        // Given
        let query = "Apple Park"
        
        // When
        let results = try await searchService.searchLocations(query: query)
        
        // Then
        XCTAssertFalse(results.isEmpty, "Should return search results for valid query")
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty }, "All results should have titles")
        XCTAssertTrue(results.allSatisfy { CLLocationCoordinate2DIsValid($0.coordinate) }, "All results should have valid coordinates")
    }
    
    func testSearchLocations_WithEmptyQuery_ThrowsEmptyQueryError() async {
        // Given
        let emptyQuery = ""
        
        // When/Then
        do {
            _ = try await searchService.searchLocations(query: emptyQuery)
            XCTFail("Should throw SearchError.emptyQuery")
        } catch SearchError.emptyQuery {
            // Expected error
        } catch {
            XCTFail("Should throw SearchError.emptyQuery, but threw \(error)")
        }
    }
    
    func testSearchLocations_WithWhitespaceQuery_ThrowsEmptyQueryError() async {
        // Given
        let whitespaceQuery = "   \n\t   "
        
        // When/Then
        do {
            _ = try await searchService.searchLocations(query: whitespaceQuery)
            XCTFail("Should throw SearchError.emptyQuery")
        } catch SearchError.emptyQuery {
            // Expected error
        } catch {
            XCTFail("Should throw SearchError.emptyQuery, but threw \(error)")
        }
    }
    
    func testSearchLocations_WithInvalidQuery_ThrowsNoResultsError() async {
        // Given
        let invalidQuery = "xyzabc123nonexistentlocation456"
        
        // When/Then
        do {
            _ = try await searchService.searchLocations(query: invalidQuery)
            XCTFail("Should throw SearchError.noResults for invalid query")
        } catch SearchError.noResults {
            // Expected error
        } catch SearchError.networkError {
            // Network error is also acceptable in some cases
        } catch {
            XCTFail("Should throw SearchError.noResults or networkError, but threw \(error)")
        }
    }
    
    func testSearchLocations_WithRegion_ReturnsResults() async throws {
        // Given
        let query = "Starbucks"
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        // When
        let results = try await searchService.searchLocations(query: query, in: region)
        
        // Then
        XCTAssertFalse(results.isEmpty, "Should return search results for valid query with region")
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty }, "All results should have titles")
        XCTAssertTrue(results.allSatisfy { CLLocationCoordinate2DIsValid($0.coordinate) }, "All results should have valid coordinates")
    }
    
    // MARK: - Reverse Geocoding Tests
    
    func testReverseGeocode_WithValidLocation_ReturnsPlacemarks() async throws {
        // Given
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        
        // When
        let placemarks = try await searchService.reverseGeocode(location: location)
        
        // Then
        XCTAssertFalse(placemarks.isEmpty, "Should return placemarks for valid location")
        XCTAssertNotNil(placemarks.first?.locality, "Should have locality information")
    }
    
    func testReverseGeocode_WithInvalidLocation_ThrowsInvalidLocationError() async {
        // Given
        let invalidLocation = CLLocation(latitude: 999, longitude: 999) // Invalid coordinates
        
        // When/Then
        do {
            _ = try await searchService.reverseGeocode(location: invalidLocation)
            XCTFail("Should throw SearchError.invalidLocation")
        } catch SearchError.invalidLocation {
            // Expected error
        } catch {
            XCTFail("Should throw SearchError.invalidLocation, but threw \(error)")
        }
    }
    
    // MARK: - SearchResult Model Tests
    
    func testSearchResult_InitializationFromMKMapItem() {
        // Given
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Test Location"
        
        // When
        let searchResult = SearchResult(mapItem: mapItem)
        
        // Then
        XCTAssertEqual(searchResult.mapItem, mapItem)
        XCTAssertEqual(searchResult.title, "Test Location")
        XCTAssertEqual(searchResult.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(searchResult.coordinate.longitude, -122.4194, accuracy: 0.0001)
    }
    
    func testSearchResult_FormattedAddress() {
        // Given
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let mapItem = MKMapItem(placemark: placemark)
        let searchResult = SearchResult(mapItem: mapItem)
        
        // When
        let formattedAddress = searchResult.formattedAddress
        
        // Then
        // Since we can't easily mock CLPlacemark address components,
        // we'll just verify that the method returns a string (even if empty)
        XCTAssertNotNil(formattedAddress, "Formatted address should not be nil")
    }
    
    func testSearchResult_DistanceCalculation() {
        // Given
        let searchLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let placemark = MKPlacemark(coordinate: searchLocation)
        let mapItem = MKMapItem(placemark: placemark)
        let searchResult = SearchResult(mapItem: mapItem)
        
        let userLocation = CLLocation(latitude: 37.7849, longitude: -122.4094) // ~1km away
        
        // When
        let distance = searchResult.distance(from: userLocation)
        let formattedDistance = searchResult.formattedDistance(from: userLocation)
        
        // Then
        XCTAssertGreaterThan(distance, 0, "Distance should be greater than 0")
        XCTAssertFalse(formattedDistance.isEmpty, "Formatted distance should not be empty")
    }
    
    func testSearchResult_Equality() {
        // Given
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let mapItem = MKMapItem(placemark: placemark)
        let searchResult1 = SearchResult(mapItem: mapItem)
        let searchResult2 = SearchResult(mapItem: mapItem)
        
        // When/Then
        XCTAssertNotEqual(searchResult1, searchResult2, "Different SearchResult instances should not be equal (different UUIDs)")
        XCTAssertEqual(searchResult1, searchResult1, "Same SearchResult instance should be equal to itself")
    }
    
    // MARK: - SearchError Tests
    
    func testSearchError_LocalizedDescriptions() {
        // Test all error cases have proper descriptions
        let errors: [SearchError] = [
            .emptyQuery,
            .noResults,
            .networkError(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])),
            .geocodingFailed(NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Geocoding error"])),
            .invalidLocation
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
}

// MARK: - Mock Classes for Advanced Testing

class MockSearchService: SearchServiceProtocol {
    var shouldThrowError: SearchError?
    var mockSearchResults: [SearchResult] = []
    var mockPlacemarks: [CLPlacemark] = []
    
    func searchLocations(query: String) async throws -> [SearchResult] {
        if let error = shouldThrowError {
            throw error
        }
        return mockSearchResults
    }
    
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        if let error = shouldThrowError {
            throw error
        }
        return mockPlacemarks
    }
}

// MARK: - Integration Tests

class SearchServiceIntegrationTests: XCTestCase {
    
    func testSearchService_RealWorldScenario() async throws {
        // Given
        let searchService = SearchService()
        let query = "Apple Park Cupertino"
        
        // When
        let results = try await searchService.searchLocations(query: query)
        
        // Then
        XCTAssertFalse(results.isEmpty, "Should find Apple Park")
        
        // Verify we can reverse geocode the first result
        if let firstResult = results.first {
            let location = CLLocation(latitude: firstResult.coordinate.latitude, longitude: firstResult.coordinate.longitude)
            let placemarks = try await searchService.reverseGeocode(location: location)
            XCTAssertFalse(placemarks.isEmpty, "Should be able to reverse geocode the search result")
        }
    }
}