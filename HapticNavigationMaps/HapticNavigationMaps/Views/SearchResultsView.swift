import SwiftUI
import MapKit
import CoreLocation

/// View for displaying search results in a list
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
            } else if searchViewModel.hasResults {
                ResultsList()
            } else if !searchViewModel.isSearchEmpty {
                NoResultsView()
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
    private func NoResultsView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("Try searching with different keywords or check your spelling.")
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
    searchViewModel.searchResults = [
        SearchResult(mapItem: {
            let placemark1 = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
            let item = MKMapItem(placemark: placemark1)
            item.name = "Apple Park"
            return item
        }()),
        SearchResult(mapItem: {
            let placemark2 = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783))
            let item = MKMapItem(placemark: placemark2)
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