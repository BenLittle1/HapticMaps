import SwiftUI
import MapKit
import CoreLocation

/// A simplified navigation interface optimized for haptic feedback and pocket use
struct HapticNavigationView: View {
    let currentStep: MKRoute.Step?
    let nextStep: MKRoute.Step?
    let distanceToNextManeuver: CLLocationDistance
    let navigationState: NavigationState
    let routeProgress: Double
    let isHapticCapable: Bool
    let onStopNavigation: () -> Void
    let onToggleMode: () -> Void
    
    @State private var isScreenLocked = false
    @State private var lastTouchTime = Date()
    
    // Keep screen awake timer
    private let screenKeepAliveTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen background for touch detection
                Color.black
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        handleScreenTouch()
                    }
                
                VStack(spacing: 0) {
                    if !isScreenLocked {
                        // Minimal header with essential info
                        HapticNavigationHeader(
                            navigationState: navigationState,
                            routeProgress: routeProgress,
                            onToggleMode: onToggleMode,
                            onStopNavigation: onStopNavigation
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Center content area
                    VStack(spacing: 24) {
                        if case .navigating = navigationState {
                            if let step = currentStep {
                                // Simplified instruction display
                                SimplifiedInstructionView(
                                    step: step,
                                    distanceToManeuver: distanceToNextManeuver,
                                    isLocked: isScreenLocked
                                )
                            } else {
                                NavigationLoadingIndicator(isLocked: isScreenLocked)
                            }
                        } else if case .arrived = navigationState {
                            ArrivalIndicator(isLocked: isScreenLocked)
                        }
                        
                        // Large touch areas for common actions
                        if !isScreenLocked {
                            HapticNavigationControls(
                                onStopNavigation: onStopNavigation,
                                onToggleMode: onToggleMode,
                                onLockScreen: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isScreenLocked = true
                                    }
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    
                    Spacer()
                    
                    // Screen unlock area
                    if isScreenLocked {
                        ScreenUnlockArea {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isScreenLocked = false
                                lastTouchTime = Date()
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(screenKeepAliveTimer) { _ in
            // Keep the screen from dimming during haptic navigation
            if case .navigating(let mode) = navigationState, mode == .haptic {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isScreenLocked)
        .animation(.easeInOut(duration: 0.3), value: navigationState)
    }
    
    private func handleScreenTouch() {
        lastTouchTime = Date()
        
        // Auto-lock screen after 30 seconds of inactivity when in haptic mode
        if case .navigating(let mode) = navigationState, mode == .haptic {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if Date().timeIntervalSince(lastTouchTime) >= 30 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isScreenLocked = true
                    }
                }
            }
        }
    }
}

/// Minimal header for haptic navigation
struct HapticNavigationHeader: View {
    let navigationState: NavigationState
    let routeProgress: Double
    let onToggleMode: () -> Void
    let onStopNavigation: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            HStack {
                ProgressView(value: routeProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 2)
                
                Text("\(Int(routeProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 40)
            }
            .padding(.horizontal, 20)
            
            // Mode indicator and controls
            HStack {
                Button(action: onToggleMode) {
                    HStack(spacing: 4) {
                        Image(systemName: currentNavigationMode.iconName)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Haptic")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: onStopNavigation) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                        
                        Text("Stop")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }
    
    private var currentNavigationMode: NavigationMode {
        if case .navigating(let mode) = navigationState {
            return mode
        }
        return .haptic
    }
}

/// Simplified instruction display for haptic navigation
struct SimplifiedInstructionView: View {
    let step: MKRoute.Step
    let distanceToManeuver: CLLocationDistance
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Large direction icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: isLocked ? 120 : 100, height: isLocked ? 120 : 100)
                
                Image(systemName: maneuverIcon)
                    .font(.system(size: isLocked ? 50 : 40, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(isLocked ? 1.2 : 1.0)
            
            if !isLocked {
                // Distance
                VStack(spacing: 4) {
                    Text(formattedDistance)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(distanceUnit)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Simplified instruction
                Text(simplifiedInstruction)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private var maneuverIcon: String {
        let instruction = step.instructions.lowercased()
        
        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("straight") || instruction.contains("continue") {
            return "arrow.up"
        } else {
            return "location.fill"
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
        return distanceToManeuver < 1000 ? "meters" : "km"
    }
    
    private var simplifiedInstruction: String {
        let instruction = step.instructions
        
        // Simplify common instructions
        if instruction.lowercased().contains("turn left") {
            return "Turn Left"
        } else if instruction.lowercased().contains("turn right") {
            return "Turn Right"
        } else if instruction.lowercased().contains("continue") || instruction.lowercased().contains("straight") {
            return "Continue Straight"
        } else {
            // Return first 50 characters for other instructions
            return String(instruction.prefix(50))
        }
    }
}

/// Large touch controls for haptic navigation
struct HapticNavigationControls: View {
    let onStopNavigation: () -> Void
    let onToggleMode: () -> Void
    let onLockScreen: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Primary actions
            HStack(spacing: 20) {
                // Stop navigation
                Button(action: onStopNavigation) {
                    VStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        
                        Text("Stop")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                // Switch to visual mode
                Button(action: onToggleMode) {
                    VStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("Visual")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                // Lock screen
                Button(action: onLockScreen) {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("Lock")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
}

/// Screen unlock area for locked haptic navigation
struct ScreenUnlockArea: View {
    let onUnlock: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Tap to unlock")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color.white.opacity(0.05))
        .onTapGesture {
            onUnlock()
        }
    }
}

/// Loading indicator for haptic navigation
struct NavigationLoadingIndicator: View {
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: isLocked ? 120 : 100, height: isLocked ? 120 : 100)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(isLocked ? 2.0 : 1.5)
            }
            
            if !isLocked {
                Text("Preparing navigation...")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

/// Arrival indicator for haptic navigation
struct ArrivalIndicator: View {
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: isLocked ? 120 : 100, height: isLocked ? 120 : 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: isLocked ? 50 : 40))
                    .foregroundColor(.green)
            }
            .scaleEffect(isLocked ? 1.2 : 1.0)
            
            if !isLocked {
                Text("Arrived!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You have reached your destination")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview

#Preview("Haptic Navigation - Active") {
    let sampleStep = MKRoute.Step()
    
    return HapticNavigationView(
        currentStep: sampleStep,
        nextStep: nil,
        distanceToNextManeuver: 150,
        navigationState: .navigating(mode: .haptic),
        routeProgress: 0.65,
        isHapticCapable: true,
        onStopNavigation: {
            print("Stop navigation")
        },
        onToggleMode: {
            print("Toggle mode")
        }
    )
}

#Preview("Haptic Navigation - Arrived") {
    return HapticNavigationView(
        currentStep: nil,
        nextStep: nil,
        distanceToNextManeuver: 0,
        navigationState: .arrived,
        routeProgress: 1.0,
        isHapticCapable: true,
        onStopNavigation: {
            print("Stop navigation")
        },
        onToggleMode: {
            print("Toggle mode")
        }
    )
} 