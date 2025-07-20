import SwiftUI
import MapKit
import CoreLocation

/// View for displaying search results, recent searches, and quick suggestions
struct SearchResultsView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    let userLocation: CLLocation?
    let onResultSelected: (SearchResult) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if searchViewModel.isLoading {
                LoadingView()
            } else if let errorMessage = searchViewModel.errorMessage {
                ErrorView(message: errorMessage) {
                    searchViewModel.performSearch()
                }
            } else if searchViewModel.isSearchEmpty && !searchViewModel.recentSearches.isEmpty {
                // Show recent searches when search is empty
                RecentSearchesView()
            } else if searchViewModel.hasResults {
                // Show search results
                ResultsList()
            } else if !searchViewModel.isSearchEmpty {
                // Show quick suggestions and no results
                VStack(spacing: 0) {
                    QuickSuggestionsView()
                    NoResultsView()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private func ErrorView(message: String, onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func RecentSearchesView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text("Recent Searches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !searchViewModel.recentSearches.isEmpty {
                    Button("Clear") {
                        // TODO: Add clear recent searches functionality
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Recent searches list
            LazyVStack(spacing: 0) {
                ForEach(searchViewModel.recentSearches.prefix(5), id: \.id) { result in
                    RecentSearchRow(
                        searchResult: result,
                        userLocation: userLocation,
                        onTap: {
                            onResultSelected(result)
                        }
                    )
                    
                    if result.id != searchViewModel.recentSearches.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    @ViewBuilder
    private func QuickSuggestionsView() -> some View {
        let suggestions = searchViewModel.getQuickSuggestions()
        
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    Text("Quick Suggestions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                searchViewModel.searchText = suggestion
                                searchViewModel.performSearch()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }
        }
    }
    
    @ViewBuilder
    private func NoResultsView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("Try a different search term or check your spelling.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func ResultsList() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchViewModel.searchResults) { result in
                    VStack(spacing: 0) {
                        SearchResultRow(
                            searchResult: result,
                            userLocation: userLocation,
                            onTap: {
                                searchViewModel.selectResult(result)
                                onResultSelected(result)
                            }
                        )
                        
                        if result.id != searchViewModel.searchResults.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Recent Search Row

struct RecentSearchRow: View {
    let searchResult: SearchResult
    let userLocation: CLLocation?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(searchResult.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !searchResult.formattedAddress.isEmpty {
                        Text(searchResult.formattedAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let userLocation = userLocation {
                    Text(searchResult.formattedDistance(from: userLocation))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let searchViewModel = SearchViewModel()
    
    // Mock recent searches
    searchViewModel.recentSearches = [
        SearchResult(mapItem: {
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
            let item = MKMapItem(placemark: placemark)
            item.name = "Apple Park"
            return item
        }()),
        SearchResult(mapItem: {
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783))
            let item = MKMapItem(placemark: placemark)
            item.name = "Golden Gate Bridge"
            return item
        }())
    ]
    
    return SearchResultsView(
        searchViewModel: searchViewModel,
        userLocation: CLLocation(latitude: 37.7749, longitude: -122.4194),
        onResultSelected: { result in
            print("Selected: \(result.title)")
        }
    )
}