import SwiftUI

/// A toggle component for switching between visual and haptic navigation modes
struct HapticModeToggle: View {
    @Binding var currentMode: NavigationMode
    @Binding var isHapticCapable: Bool
    let onModeChanged: (NavigationMode) -> Void
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 12) {
            // Mode Selection Picker
            Picker("Navigation Mode", selection: $currentMode) {
                ForEach(NavigationMode.allCases, id: \.self) { mode in
                    HStack(spacing: 8) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: currentMode) { _, newMode in
                hapticImpact.impactOccurred()
                onModeChanged(newMode)
            }
            .disabled(!isHapticCapable && currentMode == .haptic)
            
            // Haptic capability warning
            if !isHapticCapable {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    
                    Text("Haptic feedback not available on this device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Mode description
            ModeDescriptionView(mode: currentMode, isHapticCapable: isHapticCapable)
        }
    }
}

/// Description view for the current navigation mode
struct ModeDescriptionView: View {
    let mode: NavigationMode
    let isHapticCapable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .foregroundColor(mode == .haptic ? .purple : .blue)
                    .font(.system(size: 16, weight: .medium))
                
                Text("\(mode.displayName) Mode")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(modeDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var modeDescription: String {
        switch mode {
        case .visual:
            return "Full visual interface with map display and turn-by-turn directions shown on screen."
        case .haptic:
            if isHapticCapable {
                return "Simplified interface with haptic feedback for pocket navigation. Minimize screen interaction and use vibrations for directions."
            } else {
                return "Haptic feedback is not available on this device. Visual mode will be used instead."
            }
        }
    }
}

/// Compact version of the mode toggle for use in navigation interfaces
struct CompactHapticModeToggle: View {
    @Binding var currentMode: NavigationMode
    let isHapticCapable: Bool
    let onModeChanged: (NavigationMode) -> Void
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: toggleMode) {
            HStack(spacing: 6) {
                Image(systemName: currentMode.iconName)
                    .font(.system(size: 16, weight: .medium))
                
                Text(currentMode.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(currentMode == .haptic ? .purple : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((currentMode == .haptic ? Color.purple : Color.blue).opacity(0.1))
            .cornerRadius(16)
        }
        .disabled(!isHapticCapable && currentMode == .haptic)
    }
    
    private func toggleMode() {
        hapticImpact.impactOccurred()
        let newMode = currentMode == .visual ? NavigationMode.haptic : NavigationMode.visual
        
        // Only switch to haptic if device is capable
        if newMode == .haptic && !isHapticCapable {
            return
        }
        
        currentMode = newMode
        onModeChanged(newMode)
    }
}

// MARK: - Preview

#Preview("HapticModeToggle") {
    @Previewable @State var currentMode: NavigationMode = .visual
    @Previewable @State var isHapticCapable = true
    
    return VStack(spacing: 20) {
        HapticModeToggle(
            currentMode: $currentMode,
            isHapticCapable: $isHapticCapable,
            onModeChanged: { mode in
                print("Mode changed to: \(mode)")
            }
        )
        
        Divider()
        
        CompactHapticModeToggle(
            currentMode: $currentMode,
            isHapticCapable: isHapticCapable,
            onModeChanged: { mode in
                print("Compact mode changed to: \(mode)")
            }
        )
        
        Button("Toggle Haptic Capability") {
            isHapticCapable.toggle()
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        
        Spacer()
    }
    .padding()
}

#Preview("Compact Toggle") {
    @Previewable @State var currentMode: NavigationMode = .haptic
    
    return CompactHapticModeToggle(
        currentMode: $currentMode,
        isHapticCapable: true,
        onModeChanged: { mode in
            print("Mode changed to: \(mode)")
        }
    )
    .padding()
} 