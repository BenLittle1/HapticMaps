import SwiftUI
import MapKit
import CoreLocation
import CoreHaptics

/// A card component for displaying turn-by-turn navigation instructions
struct NavigationCard: View {
    let currentStep: MKRoute.Step?
    let nextStep: MKRoute.Step?
    let distanceToNextManeuver: CLLocationDistance
    let navigationState: NavigationState
    let onStopNavigation: () -> Void
    let onToggleMode: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // Navigation content
            VStack(spacing: 16) {
                // Header with mode toggle and stop button
                HStack {
                    CompactHapticModeToggle(
                        currentMode: .constant(currentNavigationMode),
                        isHapticCapable: CHHapticEngine.capabilitiesForHardware().supportsHaptics,
                        onModeChanged: { _ in
                            onToggleMode()
                        }
                    )
                    
                    Spacer()
                    
                    Button(action: {
                        onStopNavigation()
                        UIAccessibility.post(notification: .announcement, argument: DesignTokens.Accessibility.Announcements.navigationStopped)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12))
                            
                            Text("Stop")
                                .accessibleFont(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .accessibleBackgroundColor(Color.red.opacity(0.1))
                        .cornerRadius(16)
                        .accessibleBorder(.red)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Stop navigation")
                    .accessibilityHint("Stops the current navigation session")
                }
                
                // Main instruction display
                if case .arrived = navigationState {
                    ArrivalDisplay()
                } else if let step = currentStep {
                    CurrentInstructionDisplay(
                        step: step,
                        distanceToManeuver: distanceToNextManeuver
                    )
                } else {
                    NavigationLoadingDisplay()
                }
                
                // Next instruction preview
                if case .navigating = navigationState,
                   let next = nextStep,
                   navigationState != .arrived {
                    NextInstructionPreview(nextStep: next)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .accessibleBackgroundColor(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation control panel")
        .accessibilityHint("Contains current navigation instructions and controls")
    }
    
    private var currentNavigationMode: NavigationMode {
        if case .navigating(let mode) = navigationState {
            return mode
        }
        return .visual
    }
}

// MARK: - Supporting Views

/// Display for current navigation instruction
struct CurrentInstructionDisplay: View {
    let step: MKRoute.Step
    let distanceToManeuver: CLLocationDistance
    
    var body: some View {
        VStack(spacing: 12) {
            // Maneuver icon and distance
            HStack(spacing: 16) {
                // Large maneuver icon
                ZStack {
                    Circle()
                        .fill(maneuverColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: maneuverIcon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(maneuverColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Distance to maneuver
                    Text(formattedDistance)
                        .accessibleFont(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(distanceUnit)
                        .accessibleFont(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Instruction text
            Text(step.instructions)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Navigation instruction")
                .accessibilityValue(step.instructions)
                .accessibilityHint("Current turn-by-turn direction")
        }
    }
    
    private var maneuverIcon: String {
        // Determine icon based on instruction content
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("straight") || instruction.contains("continue") {
            return "arrow.up"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "flag.checkered"
        } else {
            return "arrow.up"
        }
    }
    
    private var maneuverColor: Color {
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("arrive") || instruction.contains("destination") {
            return .green
        } else if instruction.contains("left") || instruction.contains("right") {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var formattedDistance: String {
        if distanceToManeuver < 100 {
            return String(format: "%.0f", distanceToManeuver)
        } else if distanceToManeuver < 1000 {
            return String(format: "%.0f", distanceToManeuver)
        } else {
            return String(format: "%.1f", distanceToManeuver / 1000)
        }
    }
    
    private var distanceUnit: String {
        if distanceToManeuver < 1000 {
            return "meters"
        } else {
            return "km"
        }
    }
}

/// Preview of the next instruction
struct NextInstructionPreview: View {
    let nextStep: MKRoute.Step
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 12) {
                Text("Then")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Image(systemName: nextManeuverIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text(nextStep.instructions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
        }
    }
    
    private var nextManeuverIcon: String {
        let instruction = nextStep.instructions.lowercased()
        
        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("straight") || instruction.contains("continue") {
            return "arrow.up"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "flag.checkered"
        } else {
            return "arrow.up"
        }
    }
}

/// Display when navigation is loading or calculating
struct NavigationLoadingDisplay: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calculating...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Preparing navigation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

/// Display when user has arrived at destination
struct ArrivalDisplay: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arrived!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("You have reached your destination")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Extensions

extension NavigationMode {
    var iconName: String {
        switch self {
        case .visual:
            return "eye.fill"
        case .haptic:
            return "hand.tap.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var navigationState: NavigationState = .navigating(mode: .visual)
    
    // Create sample route step
    let sampleStep = MKRoute.Step()
    let nextStep = MKRoute.Step()
    
    return VStack {
        Spacer()
        
        NavigationCard(
            currentStep: sampleStep,
            nextStep: nextStep,
            distanceToNextManeuver: 150,
            navigationState: navigationState,
            onStopNavigation: {
                print("Stop navigation")
            },
            onToggleMode: {
                if case .navigating(let mode) = navigationState {
                    let newMode: NavigationMode = mode == .visual ? .haptic : .visual
                    navigationState = .navigating(mode: newMode)
                }
            }
        )
    }
    .background(Color(.systemGray6))
}