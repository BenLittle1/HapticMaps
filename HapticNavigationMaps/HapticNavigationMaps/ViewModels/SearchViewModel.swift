import Foundation
import SwiftUI
import MapKit
import CoreLocation

/// ViewModel for managing search functionality and state
@MainActor
class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedResult: SearchResult?
    
    // MARK: - Private Properties
    
    private let searchService: SearchServiceProtocol
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(searchService: SearchServiceProtocol = SearchService()) {
        self.searchService = searchService
        
        // Set up search text observation with debouncing
        setupSearchTextObservation()
    }
    
    // MARK: - Public Methods
    
    /// Perform search with the current search text
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }
        
        // Cancel any existing search task
        searchTask?.cancel()
        
        searchTask = Task {
            await executeSearch(query: searchText)
        }
    }
    
    /// Perform search with region bias for more relevant results
    func performSearch(in region: MKCoordinateRegion) {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            await executeSearchWithRegion(query: searchText, region: region)
        }
    }
    
    /// Clear search results and reset state
    func clearResults() {
        searchResults = []
        errorMessage = nil
        selectedResult = nil
    }
    
    /// Cancel current search and reset state
    func cancelSearch() {
        searchTask?.cancel()
        searchText = ""
        isSearching = false
        clearResults()
    }
    
    /// Select a search result
    func selectResult(_ result: SearchResult) {
        selectedResult = result
        isSearching = false
    }
    
    // MARK: - Private Methods
    
    private func setupSearchTextObservation() {
        // Debounce search text changes to avoid excessive API calls
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
    
    private func executeSearch(query: String) async {
        guard !Task.isCancelled else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await searchService.searchLocations(query: query)
            
            guard !Task.isCancelled else { return }
            
            searchResults = results
            
        } catch {
            guard !Task.isCancelled else { return }
            
            handleSearchError(error)
        }
        
        isLoading = false
    }
    
    private func executeSearchWithRegion(query: String, region: MKCoordinateRegion) async {
        guard !Task.isCancelled else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if SearchService has region-based search method
            if let searchService = searchService as? SearchService {
                let results = try await searchService.searchLocations(query: query, in: region)
                
                guard !Task.isCancelled else { return }
                
                searchResults = results
            } else {
                // Fallback to regular search
                let results = try await searchService.searchLocations(query: query)
                
                guard !Task.isCancelled else { return }
                
                searchResults = results
            }
            
        } catch {
            guard !Task.isCancelled else { return }
            
            handleSearchError(error)
        }
        
        isLoading = false
    }
    
    private func handleSearchError(_ error: Error) {
        if let searchError = error as? SearchError {
            errorMessage = searchError.localizedDescription
        } else {
            errorMessage = "An unexpected error occurred while searching."
        }
        
        searchResults = []
    }
    
    // MARK: - Combine Support
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Extensions

extension SearchViewModel {
    /// Check if there are search results to display
    var hasResults: Bool {
        !searchResults.isEmpty
    }
    
    /// Check if search is empty
    var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Check if we should show the search results list
    var shouldShowResults: Bool {
        isSearching && (hasResults || isLoading || errorMessage != nil)
    }
}

import Combine