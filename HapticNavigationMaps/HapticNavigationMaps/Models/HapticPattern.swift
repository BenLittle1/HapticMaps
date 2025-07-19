import Foundation
import CoreHaptics

/// Represents a haptic feedback pattern for navigation cues
struct HapticPattern {
    let events: [CHHapticEvent]
    let duration: TimeInterval
    let intensity: Float
    
    init(events: [CHHapticEvent], duration: TimeInterval, intensity: Float = 1.0) {
        self.events = events
        self.duration = duration
        self.intensity = min(max(intensity, 0.0), 1.0) // Clamp between 0 and 1
    }
}

/// Predefined haptic patterns for navigation
extension HapticPattern {
    /// Single sharp tap for left turns
    static var leftTurn: HapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        )
        return HapticPattern(events: [event], duration: 0.1, intensity: 1.0)
    }
    
    /// Double tap pattern for right turns
    static var rightTurn: HapticPattern {
        let firstTap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        )
        
        let secondTap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0.2
        )
        
        return HapticPattern(events: [firstTap, secondTap], duration: 0.4, intensity: 1.0)
    }
    
    /// Gentle continuous pattern for straight ahead
    static var continueStraight: HapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0,
            duration: 0.5
        )
        return HapticPattern(events: [event], duration: 0.5, intensity: 0.3)
    }
    
    /// Celebratory pattern for arrival
    static var arrival: HapticPattern {
        let events = (0..<3).map { index in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: TimeInterval(index) * 0.15
            )
        }
        return HapticPattern(events: events, duration: 0.6, intensity: 0.8)
    }
}