import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

/// ViewModel for managing search functionality and state with optimized performance
@MainActor
class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedResult: SearchResult?
    @Published var recentSearches: [SearchResult] = []
    
    // MARK: - Private Properties
    
    private let searchService: SearchServiceProtocol
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance optimizations
    private var searchCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxRecentSearches = 10
    
    // Fast debouncing for immediate feedback
    private let fastDebounceDelay: RunLoop.SchedulerTimeType.Stride = .milliseconds(150)
    
    // MARK: - Initialization
    
    init(searchService: SearchServiceProtocol = SearchService()) {
        self.searchService = searchService
        loadRecentSearches()
        setupSearchTextObservation()
    }
    
    // MARK: - Public Methods
    
    /// Perform search with the current search text
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        // Show immediate cached results if available
        if let cachedResult = getCachedResult(for: query) {
            print("🔍 SearchViewModel: Using cached results for '\(query)'")
            searchResults = cachedResult.results
            errorMessage = nil
        }
        
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Start fresh search in background
        searchTask = Task {
            await executeSearch(query: query)
        }
    }
    
    /// Perform search with region bias for more relevant results
    func performSearch(in region: MKCoordinateRegion) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        // Check cache first
        if let cachedResult = getCachedResult(for: query) {
            searchResults = cachedResult.results
            errorMessage = nil
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            await executeSearchWithRegion(query: query, region: region)
        }
    }
    
    /// Show recent searches when search is empty
    func showRecentSearches() {
        if searchText.isEmpty {
            searchResults = recentSearches
            isSearching = true
        }
    }
    
    /// Clear search results and reset state
    func clearResults() {
        searchResults = []
        errorMessage = nil
        selectedResult = nil
        isSearching = false
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
        
        // Add to recent searches
        addToRecentSearches(result)
    }
    
    /// Quick search suggestions based on input
    func getQuickSuggestions() -> [String] {
        let query = searchText.lowercased()
        if query.isEmpty { return [] }
        
        let suggestions = [
            "restaurant", "gas station", "coffee", "pharmacy", "grocery store",
            "hospital", "bank", "atm", "parking", "hotel", "airport"
        ].filter { $0.contains(query) }
        
        return Array(suggestions.prefix(3))
    }
    
    // MARK: - Private Methods
    
    private func setupSearchTextObservation() {
        // Fast debouncing for immediate feedback
        $searchText
            .debounce(for: fastDebounceDelay, scheduler: RunLoop.main)
            .sink { [weak self] newText in
                Task { @MainActor in
                    if newText.isEmpty {
                        self?.clearResults()
                    } else {
                        self?.isSearching = true
                        self?.performSearch()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func executeSearch(query: String) async {
        guard !Task.isCancelled else { return }
        
        // Only show loading if we don't have cached results
        if searchResults.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let results = try await searchService.searchLocations(query: query)
            
            guard !Task.isCancelled else { return }
            
            // Cache the results
            cacheSearchResult(query: query, results: results)
            
            // Update UI
            searchResults = results
            
        } catch {
            guard !Task.isCancelled else { return }
            
            // Only show error if we don't have cached results
            if searchResults.isEmpty {
                handleSearchError(error)
            }
        }
        
        isLoading = false
    }
    
    private func executeSearchWithRegion(query: String, region: MKCoordinateRegion) async {
        guard !Task.isCancelled else { return }
        
        if searchResults.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let results: [SearchResult]
            
            if let searchService = searchService as? SearchService {
                results = try await searchService.searchLocations(query: query, in: region)
            } else {
                results = try await searchService.searchLocations(query: query)
            }
            
            guard !Task.isCancelled else { return }
            
            cacheSearchResult(query: query, results: results)
            searchResults = results
            
        } catch {
            guard !Task.isCancelled else { return }
            
            if searchResults.isEmpty {
                handleSearchError(error)
            }
        }
        
        isLoading = false
    }
    
    private func handleSearchError(_ error: Error) {
        if let searchError = error as? SearchError {
            errorMessage = searchError.localizedDescription
        } else {
            errorMessage = "Search failed. Please try again."
        }
        
        // Don't clear results if we have cached ones
        if searchResults.isEmpty {
            searchResults = []
        }
    }
    
    // MARK: - Caching
    
    private func getCachedResult(for query: String) -> CachedSearchResult? {
        let cacheKey = query.lowercased()
        guard let cached = searchCache[cacheKey] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationTime {
            searchCache.removeValue(forKey: cacheKey)
            return nil
        }
        
        return cached
    }
    
    private func cacheSearchResult(query: String, results: [SearchResult]) {
        let cacheKey = query.lowercased()
        let cachedResult = CachedSearchResult(results: results, timestamp: Date())
        
        searchCache[cacheKey] = cachedResult
        
        // Limit cache size
        if searchCache.count > maxCacheSize {
            // Remove oldest entries
            let sortedKeys = searchCache.keys.sorted { key1, key2 in
                searchCache[key1]!.timestamp < searchCache[key2]!.timestamp
            }
            
            for key in sortedKeys.prefix(searchCache.count - maxCacheSize) {
                searchCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Recent Searches
    
    private func addToRecentSearches(_ result: SearchResult) {
        // Remove if already exists
        recentSearches.removeAll { $0.id == result.id }
        
        // Add to beginning
        recentSearches.insert(result, at: 0)
        
        // Limit size
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        if let encoded = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(encoded, forKey: "RecentSearches")
        }
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "RecentSearches"),
           let decoded = try? JSONDecoder().decode([SearchResult].self, from: data) {
            recentSearches = decoded
        }
    }
}

// MARK: - Cached Search Result

private struct CachedSearchResult {
    let results: [SearchResult]
    let timestamp: Date
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
    
    /// Check if showing recent searches
    var isShowingRecentSearches: Bool {
        isSearchEmpty && hasResults
    }
}