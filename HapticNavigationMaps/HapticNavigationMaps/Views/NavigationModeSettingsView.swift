import SwiftUI
import CoreHaptics

/// Settings view for navigation mode preferences and haptic feedback configuration
struct NavigationModeSettingsView: View {
    @StateObject private var userPreferences = UserPreferences.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isHapticCapable: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    
    var body: some View {
        NavigationView {
            Form {
                // Navigation Mode Selection
                Section("Navigation Mode") {
                    HapticModeToggle(
                        currentMode: $userPreferences.preferredNavigationMode,
                        isHapticCapable: $isHapticCapable,
                        onModeChanged: { mode in
                            userPreferences.preferredNavigationMode = mode
                        }
                    )
                }
                
                // Haptic Settings
                Section("Haptic Settings") {
                    Toggle("Enable Haptic Feedback", isOn: $userPreferences.isHapticFeedbackEnabled)
                        .disabled(!isHapticCapable)
                    
                    if !isHapticCapable {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text("Haptic feedback is not available on this device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Screen Management
                Section("Screen Management") {
                    Toggle("Auto-lock screen in haptic mode", isOn: $userPreferences.autoLockScreenInHapticMode)
                    
                    if userPreferences.autoLockScreenInHapticMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Screen lock timeout: \(Int(userPreferences.screenLockTimeout)) seconds")
                                .font(.subheadline)
                            
                            Slider(
                                value: $userPreferences.screenLockTimeout,
                                in: 10...120,
                                step: 10
                            ) {
                                Text("Lock timeout")
                            } minimumValueLabel: {
                                Text("10s")
                                    .font(.caption)
                            } maximumValueLabel: {
                                Text("2m")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Toggle("Keep screen awake during haptic navigation", isOn: $userPreferences.keepScreenAwakeInHapticMode)
                }
                
                // Advanced Settings
                Section("Advanced") {
                    Button("Reset to Defaults") {
                        userPreferences.resetToDefaults()
                    }
                    .foregroundColor(.red)
                    
                    if userPreferences.hasRestorableNavigationState {
                        Button("Clear Saved Navigation State") {
                            userPreferences.clearNavigationState()
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                // Information Section
                Section("About Haptic Navigation") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "hand.tap",
                            title: "Haptic Mode",
                            description: "Navigate with your phone in your pocket using vibration patterns for directions."
                        )
                        
                        InfoRow(
                            icon: "eye",
                            title: "Visual Mode",
                            description: "Traditional navigation with full map display and visual turn-by-turn instructions."
                        )
                        
                        InfoRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Mode Switching",
                            description: "Switch between modes anytime during navigation. Your progress will be preserved."
                        )
                    }
                }
            }
            .navigationTitle("Navigation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Information row for settings descriptions
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 20))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationModeSettingsView()
} 