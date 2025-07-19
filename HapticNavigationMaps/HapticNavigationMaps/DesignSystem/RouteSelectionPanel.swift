import SwiftUI
import MapKit

/// A panel component for selecting between multiple route options
struct RouteSelectionPanel: View {
    let routes: [MKRoute]
    @Binding var selectedRouteIndex: Int
    let onRouteSelected: (MKRoute) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Route")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(routes.count) route\(routes.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 20)
            
            // Route options
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                        RouteOptionRow(
                            route: route,
                            routeNumber: index + 1,
                            isSelected: index == selectedRouteIndex,
                            onTap: {
                                selectedRouteIndex = index
                                onRouteSelected(route)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 300)
            
            Spacer(minLength: 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
    }
}

/// Individual route option row
struct RouteOptionRow: View {
    let route: MKRoute
    let routeNumber: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Route number indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                        .frame(width: 32, height: 32)
                    
                    Text("\(routeNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 16) {
                        // Travel time
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            
                            Text(formattedTravelTime)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        // Distance
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            
                            Text(formattedDistance)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    
                    // Route description
                    Text(routeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
    
    private var routeDescription: String {
        // Generate a simple route description based on the route name or steps
        if !route.name.isEmpty {
            return route.name
        } else if !route.steps.isEmpty {
            return "Via \(route.steps.first?.instructions ?? "main roads")"
        } else {
            return "Standard route"
        }
    }
}

#Preview {
    @Previewable @State var selectedIndex = 0
    
    // Create sample routes for preview
    let sampleRoutes = [MKRoute(), MKRoute(), MKRoute()]
    
    return VStack {
        Spacer()
        
        RouteSelectionPanel(
            routes: sampleRoutes,
            selectedRouteIndex: $selectedIndex,
            onRouteSelected: { route in
                print("Route selected")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .background(Color(.systemGray6))
}