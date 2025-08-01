import SwiftUI
import MapKit
import CoreLocation

/// A row component for displaying search results
struct SearchResultRow: View {
    let searchResult: SearchResult
    let userLocation: CLLocation?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Location icon
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(searchResult.title)
                        .accessibleFont(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? nil : 1)
                    
                    // Subtitle/Address
                    if !searchResult.subtitle.isEmpty {
                        Text(searchResult.subtitle)
                            .accessibleFont(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? nil : 2)
                    } else if !searchResult.formattedAddress.isEmpty {
                        Text(searchResult.formattedAddress)
                            .accessibleFont(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? nil : 2)
                    }
                }
                
                Spacer()
                
                // Distance (if user location is available)
                if let userLocation = userLocation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(searchResult.formattedDistance(from: userLocation))
                            .accessibleFont(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(.tertiaryLabel))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(searchResultAccessibilityLabel)
        .accessibilityHint("Double tap to select this location")
        .frame(minWidth: 44, minHeight: 44)
    }
    
    private var searchResultAccessibilityLabel: String {
        var label = searchResult.title
        
        if !searchResult.subtitle.isEmpty {
            label += ", \(searchResult.subtitle)"
        } else if !searchResult.formattedAddress.isEmpty {
            label += ", \(searchResult.formattedAddress)"
        }
        
        if let userLocation = userLocation {
            let distance = searchResult.formattedDistance(from: userLocation)
            label += ", \(distance) away"
        }
        
        return label
    }
}

#Preview {
    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
    let sampleMapItem = MKMapItem(placemark: placemark)
    sampleMapItem.name = "Apple Park"
    
    let searchResult = SearchResult(mapItem: sampleMapItem)
    let userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    
    return VStack {
        SearchResultRow(
            searchResult: searchResult,
            userLocation: userLocation,
            onTap: {
                print("Search result tapped")
            }
        )
        
        Divider()
        
        SearchResultRow(
            searchResult: searchResult,
            userLocation: nil,
            onTap: {
                print("Search result tapped")
            }
        )
    }
}