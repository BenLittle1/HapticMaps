import Foundation
import CoreHaptics

/// Navigation pattern types for haptic feedback and audio fallback
enum NavigationPatternType: String, CaseIterable {
    case leftTurn = "leftTurn"
    case rightTurn = "rightTurn"
    case continueStraight = "continueStraight"
    case arrival = "arrival"
    
    /// Audio frequency for audio fallback (in Hz)
    var audioFrequency: Float {
        switch self {
        case .leftTurn:
            return 440.0 // A4 note
        case .rightTurn:
            return 523.25 // C5 note
        case .continueStraight:
            return 329.63 // E4 note
        case .arrival:
            return 659.25 // E5 note
        }
    }
    
    /// Audio pattern description for accessibility
    var audioDescription: String {
        switch self {
        case .leftTurn:
            return "Turn left"
        case .rightTurn:
            return "Turn right"
        case .continueStraight:
            return "Continue straight"
        case .arrival:
            return "Arrived at destination"
        }
    }
}

/// Represents a haptic feedback pattern for navigation cues
struct HapticPattern {
    let events: [CHHapticEvent]
    let duration: TimeInterval
    let intensity: Float
    let patternType: NavigationPatternType
    
    init(events: [CHHapticEvent], duration: TimeInterval, intensity: Float = 1.0, patternType: NavigationPatternType) {
        self.events = events
        self.duration = duration
        self.intensity = min(max(intensity, 0.0), 1.0) // Clamp between 0 and 1
        self.patternType = patternType
    }
    
    /// Audio frequency for fallback audio cues
    var audioFrequency: Float {
        return patternType.audioFrequency
    }
    
    /// Raw value for pattern identification
    var rawValue: String {
        return patternType.rawValue
    }
    
    /// Audio description for accessibility
    var audioDescription: String {
        return patternType.audioDescription
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
        return HapticPattern(events: [event], duration: 0.1, intensity: 1.0, patternType: .leftTurn)
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
        
        return HapticPattern(events: [firstTap, secondTap], duration: 0.4, intensity: 1.0, patternType: .rightTurn)
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
        return HapticPattern(events: [event], duration: 0.5, intensity: 0.3, patternType: .continueStraight)
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
        return HapticPattern(events: events, duration: 0.6, intensity: 0.8, patternType: .arrival)
    }
}