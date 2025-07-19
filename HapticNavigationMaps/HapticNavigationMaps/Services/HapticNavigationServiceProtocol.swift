import Foundation
import CoreHaptics

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
}

enum HapticEngineState {
    case notInitialized
    case initializing
    case running
    case stopped
    case error(Error)
}

enum HapticNavigationError: Error, LocalizedError {
    case engineNotAvailable
    case engineNotInitialized
    case patternCreationFailed
    case playbackFailed(Error)
    
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