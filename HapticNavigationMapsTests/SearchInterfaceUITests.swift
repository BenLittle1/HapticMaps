import XCTest
import SwiftUI
@testable import HapticNavigationMaps

final class SearchInterfaceUITests: XCTestCase {
    
    func testSearchBarDisplaysCorrectly() throws {
        // Test that SearchBar displays with correct placeholder and initial state
        let searchBar = SearchBar(
            text: .constant(""),
            isSearching: .constant(false),
            placeholder: "Search for places..."
        )
        
        // This is a basic structural test - in a real UI test environment,
        // we would use XCUIApplication to test the actual UI
        XCTAssertNotNil(searchBar)
    }
    
    func testSearchBarStateChanges() throws {
        // Test search bar state management
        var searchText = ""
        var isSearching = false
        
        let searchBar = SearchBar(
            text: .init(
                get: { searchText },
                set: { searchText = $0 }
            ),
            isSearching: .init(
                get: { isSearching },
                set: { isSearching = $0 }
            ),
            placeholder: "Search for places..."
        )
        
        XCTAssertNotNil(searchBar)
        XCTAssertEqual(searchText, "")
        XCTAssertFalse(isSearching)
    }
    
    func testSearchResultRowDisplaysCorrectly() throws {
        // Create a mock search result
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Apple Park"
        
        let searchResult = SearchResult(mapItem: mapItem)
        let userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        var tapped = false
        let searchResultRow = SearchResultRow(
            searchResult: searchResult,
            userLocation: userLocation,
            onTap: { tapped = true }
        )
        
        XCTAssertNotNil(searchResultRow)
        XCTAssertEqual(searchResult.title, "Apple Park")
        XCTAssertFalse(tapped)
    }
    
    func testSearchResultsViewDisplaysCorrectly() throws {
        // Create a mock search view model with results
        let searchViewModel = SearchViewModel()
        
        // Create mock search results
        let placemark1 = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
        let mapItem1 = MKMapItem(placemark: placemark1)
        mapItem1.name = "Apple Park"
        
        let placemark2 = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783))
        let mapItem2 = MKMapItem(placemark: placemark2)
        mapItem2.name = "Golden Gate Bridge"
        
        searchViewModel.searchResults = [
            SearchResult(mapItem: mapItem1),
            SearchResult(mapItem: mapItem2)
        ]
        
        let userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        var selectedResult: SearchResult?
        
        let searchResultsView = SearchResultsView(
            searchViewModel: searchViewModel,
            userLocation: userLocation,
            onResultSelected: { result in
                selectedResult = result
            }
        )
        
        XCTAssertNotNil(searchResultsView)
        XCTAssertEqual(searchViewModel.searchResults.count, 2)
        XCTAssertEqual(searchViewModel.searchResults[0].title, "Apple Park")
        XCTAssertEqual(searchViewModel.searchResults[1].title, "Golden Gate Bridge")
        XCTAssertNil(selectedResult)
    }
    
    func testSearchViewModelStateManagement() throws {
        let searchViewModel = SearchViewModel()
        
        // Test initial state
        XCTAssertEqual(searchViewModel.searchText, "")
        XCTAssertEqual(searchViewModel.searchResults.count, 0)
        XCTAssertFalse(searchViewModel.isSearching)
        XCTAssertFalse(searchViewModel.isLoading)
        XCTAssertNil(searchViewModel.errorMessage)
        XCTAssertNil(searchViewModel.selectedResult)
        
        // Test computed properties
        XCTAssertFalse(searchViewModel.hasResults)
        XCTAssertTrue(searchViewModel.isSearchEmpty)
        XCTAssertFalse(searchViewModel.shouldShowResults)
    }
    
    func testSearchViewModelClearResults() throws {
        let searchViewModel = SearchViewModel()
        
        // Add some mock data
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Test Location"
        
        searchViewModel.searchResults = [SearchResult(mapItem: mapItem)]
        searchViewModel.errorMessage = "Test error"
        searchViewModel.selectedResult = SearchResult(mapItem: mapItem)
        
        // Clear results
        searchViewModel.clearResults()
        
        // Verify state is cleared
        XCTAssertEqual(searchViewModel.searchResults.count, 0)
        XCTAssertNil(searchViewModel.errorMessage)
        XCTAssertNil(searchViewModel.selectedResult)
    }
    
    func testSearchViewModelCancelSearch() throws {
        let searchViewModel = SearchViewModel()
        
        // Set some state
        searchViewModel.searchText = "test query"
        searchViewModel.isSearching = true
        
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Test Location"
        
        searchViewModel.searchResults = [SearchResult(mapItem: mapItem)]
        
        // Cancel search
        searchViewModel.cancelSearch()
        
        // Verify state is reset
        XCTAssertEqual(searchViewModel.searchText, "")
        XCTAssertFalse(searchViewModel.isSearching)
        XCTAssertEqual(searchViewModel.searchResults.count, 0)
    }
    
    func testSearchViewModelSelectResult() throws {
        let searchViewModel = SearchViewModel()
        
        // Create a mock search result
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Test Location"
        let searchResult = SearchResult(mapItem: mapItem)
        
        searchViewModel.isSearching = true
        
        // Select result
        searchViewModel.selectResult(searchResult)
        
        // Verify result is selected and search state is updated
        XCTAssertEqual(searchViewModel.selectedResult?.title, "Test Location")
        XCTAssertFalse(searchViewModel.isSearching)
    }
    
    // MARK: - Accessibility Tests
    
    func testSearchBarAccessibilityLabels() {
        // Given: A SearchBar component
        @State var searchText = "Test Location"
        @State var isSearching = false
        
        let searchBar = SearchBar(
            text: $searchText,
            isSearching: $isSearching,
            placeholder: "Search for places...",
            onSearchButtonClicked: {},
            onCancelButtonClicked: {}
        )
        
        // Then: SearchBar should have accessibility support
        XCTAssertNotNil(searchBar.body)
        XCTAssertEqual(searchBar.text.wrappedValue, "Test Location")
        XCTAssertEqual(searchBar.placeholder, "Search for places...")
    }
    
    func testSearchResultRowAccessibilitySupport() {
        // Given: A search result with accessibility service
        let searchResult = createMockSearchResult()
        let userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let searchRow = SearchResultRow(
            searchResult: searchResult,
            userLocation: userLocation,
            onTap: {}
        )
        
        // Then: SearchRow should be accessible
        XCTAssertNotNil(searchRow.body)
        
        // Test accessibility service integration
        let accessibilityService = AccessibilityService.shared
        XCTAssertNotNil(accessibilityService.preferredContentSizeCategory)
        XCTAssertTrue(accessibilityService.isAudioFeedbackEnabled || 
                     accessibilityService.isSpeechFeedbackEnabled ||
                     accessibilityService.isVisualFeedbackEnabled)
    }
    
    func testSearchWithDynamicTypeSupport() {
        // Given: Large text accessibility enabled
        let accessibilityService = AccessibilityService.shared
        accessibilityService.preferredContentSizeCategory = .accessibilityLarge
        
        // When: Creating search components
        let searchResult = createMockSearchResult()
        let searchRow = SearchResultRow(
            searchResult: searchResult,
            userLocation: nil,
            onTap: {}
        )
        
        // Then: Components should adapt to large text
        XCTAssertNotNil(searchRow.body)
        XCTAssertTrue(accessibilityService.isLargeTextEnabled())
        
        // Reset for other tests
        accessibilityService.preferredContentSizeCategory = .medium
    }
    
    func testSearchAccessibilityAnnouncements() {
        // Given: AccessibilityService for announcements
        let accessibilityService = AccessibilityService.shared
        
        // When: Making search-related announcements
        accessibilityService.announceAccessibility("Search completed")
        accessibilityService.announceAccessibility("No results found")
        
        // Then: Announcements should work without errors
        XCTAssertNotNil(accessibilityService)
    }
}

import MapKit
import CoreLocation