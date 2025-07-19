import Foundation
import CoreHaptics

@MainActor
protocol HapticNavigationServiceProtocol: ObservableObject {
    var isHapticModeEnabled: Bool { get set }
    var isHapticCapable: Bool { get }
    var engineState: HapticEngineState { get }
    
    func initializeHapticEngine() throws
    func playTurnLeftPattern() async throws
    func playTurnRightPattern() async throws
    func playContinueStraightPattern() async throws
    func playArrivalPattern() async throws
    func stopAllHaptics()
    func resetEngine() throws
    
    // Background navigation support
    func startNavigationBackgroundTask()
    func stopNavigationBackgroundTask()
}

enum HapticEngineState: Equatable {
    case notInitialized
    case initializing
    case running
    case stopped
    case error(Error)
    
    static func == (lhs: HapticEngineState, rhs: HapticEngineState) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized),
             (.initializing, .initializing),
             (.running, .running),
             (.stopped, .stopped):
            return true
        case (.error, .error):
            return true // Consider all error states equal for comparison purposes
        default:
            return false
        }
    }
}

enum HapticNavigationError: Error, LocalizedError, Equatable {
    case engineNotAvailable
    case engineNotInitialized
    case patternCreationFailed
    case playbackFailed(Error)
    
    static func == (lhs: HapticNavigationError, rhs: HapticNavigationError) -> Bool {
        switch (lhs, rhs) {
        case (.engineNotAvailable, .engineNotAvailable),
             (.engineNotInitialized, .engineNotInitialized),
             (.patternCreationFailed, .patternCreationFailed):
            return true
        case (.playbackFailed, .playbackFailed):
            return true // Consider all playback failures equal for testing purposes
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .engineNotAvailable:
            return "Haptic engine is not available on this device"
        case .engineNotInitialized:
            return "Haptic engine has not been initialized"
        case .patternCreationFailed:
            return "Failed to create haptic pattern"
        case .playbackFailed(let error):
            return "Haptic playback failed: \(error.localizedDescription)"
        }
    }
}