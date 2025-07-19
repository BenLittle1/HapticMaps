import SwiftUI
import MapKit

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
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Walking directions")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .font(.system(size: DesignTokens.IconSize.md))
                    }
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
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            
            Text(label)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }
}



#Preview {
    let sampleRoute = MKRoute()
    
    return VStack {
        Spacer()
        
        RouteInfoPanel(
            route: sampleRoute,
            onStartNavigation: {
                print("Start navigation tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .background(DesignTokens.Colors.surface)
}