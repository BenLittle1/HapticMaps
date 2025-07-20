import SwiftUI
import MapKit
import CoreLocation

/// A panel component for displaying route information including time and distance estimates
struct RouteInfoPanel: View {
    let route: MKRoute
    let onStartNavigation: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Handle bar
            handleBar()
            
            // Route information content
            VStack(spacing: DesignTokens.Spacing.md) {
                // Header section
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Route Information")
                            .accessibleFont(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Walking directions")
                            .accessibleFont(DesignTokens.Typography.subheadline)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .font(.system(size: DesignTokens.IconSize.md))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Close route information")
                    .accessibilityHint("Dismisses the route information panel")
                }
                
                // Route metrics section
                HStack(spacing: DesignTokens.Spacing.xxl) {
                    // Travel time metric
                    RouteMetricView(
                        icon: "clock",
                        iconColor: DesignTokens.Colors.primary,
                        value: formattedTravelTime,
                        label: "Travel time"
                    )
                    
                    // Distance metric
                    RouteMetricView(
                        icon: "location",
                        iconColor: DesignTokens.Colors.success,
                        value: formattedDistance,
                        label: "Distance"
                    )
                    
                    Spacer()
                }
                
                // Start navigation button using MapButton
                MapButton.primary(
                    action: onStartNavigation,
                    icon: "location.fill",
                    label: "Start Navigation",
                    size: .large
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.cardPadding)
            .padding(.bottom, DesignTokens.Spacing.cardPadding)
        }
        .panelStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route information panel")
        .accessibilityHint("Contains route details and navigation options")
        .accessibilityValue("Travel time: \(formattedTravelTime), Distance: \(formattedDistance)")
    }
    
    private var formattedTravelTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: route.expectedTravelTime) ?? "Unknown"
    }
    
    private var formattedDistance: String {
        let formatter = MKDistanceFormatter()
        return formatter.string(fromDistance: route.distance)
    }
}

// MARK: - Supporting Views

/// A metric display component for route information
struct RouteMetricView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: DesignTokens.IconSize.sm))
                
                Text(value)
                    .accessibleFont(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            
            Text(label)
                .accessibleFont(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }
}

// MARK: - Tapped Location Panel

/// Panel for displaying options for a tapped location on the map
struct TappedLocationPanel: View {
    let tappedLocation: TappedLocation
    let onGetDirections: () -> Void
    let onDismiss: () -> Void
    
    @State private var locationName: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            VStack(spacing: 20) {
                // Header with location info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(locationName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(formatCoordinate(tappedLocation.coordinate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("✕") {
                        onDismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Get Directions button
                    Button(action: onGetDirections) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            Text("Get Directions")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .frame(minHeight: 50)
                    
                    // Additional actions row
                    HStack(spacing: 12) {
                        // Share location
                        Button(action: {
                            shareLocation()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("Share")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Mark as favorite (placeholder)
                        Button(action: {
                            // TODO: Implement favorite functionality
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "heart")
                                    .font(.system(size: 20))
                                Text("Save")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // More options
                        Button(action: {
                            // TODO: Implement more options
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20))
                                Text("More")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        .onAppear {
            loadLocationName()
        }
    }
    
    // MARK: - Private Methods
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        
        return String(format: "%.4f°%@ %.4f°%@", 
                     abs(coordinate.latitude), latDirection,
                     abs(coordinate.longitude), lonDirection)
    }
    
    private func loadLocationName() {
        // Perform reverse geocoding to get a readable name
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: tappedLocation.coordinate.latitude, 
                                longitude: tappedLocation.coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    if let name = placemark.name {
                        locationName = name
                    } else if let thoroughfare = placemark.thoroughfare {
                        locationName = thoroughfare
                    } else if let locality = placemark.locality {
                        locationName = locality
                    } else {
                        locationName = "Dropped Pin"
                    }
                } else {
                    locationName = "Dropped Pin"
                }
            }
        }
    }
    
    private func shareLocation() {
        let coordinate = tappedLocation.coordinate
        let urlString = "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)"
        
        if let url = URL(string: urlString) {
            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityViewController, animated: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TappedLocationPanel(
        tappedLocation: TappedLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        onGetDirections: {},
        onDismiss: {}
    )
    .padding()
}