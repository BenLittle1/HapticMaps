import SwiftUI
import MapKit

/// A panel component for displaying route information including time and distance estimates
struct RouteInfoPanel: View {
    let route: MKRoute
    let onStartNavigation: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // Route information
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Route Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Walking directions")
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
                
                // Time and distance
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                            
                            Text(formattedTravelTime)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Travel time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            
                            Text(formattedDistance)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Start navigation button
                Button(action: onStartNavigation) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Start Navigation")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
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
    .background(Color(.systemGray6))
}