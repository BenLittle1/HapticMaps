import Foundation
import CoreHaptics
import Combine

@MainActor
class HapticNavigationService: HapticNavigationServiceProtocol {
    @Published var isHapticModeEnabled: Bool = false
    @Published var engineState: HapticEngineState = .notInitialized
    
    private var hapticEngine: CHHapticEngine?
    private var currentPlayer: CHHapticPatternPlayer?
    
    var isHapticCapable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    init() {
        // Only enable haptic mode if device supports it
        self.isHapticModeEnabled = isHapticCapable
    }
    
    func initializeHapticEngine() throws {
        guard isHapticCapable else {
            throw HapticNavigationError.engineNotAvailable
        }
        
        engineState = .initializing
        
        do {
            hapticEngine = try CHHapticEngine()
            setupEngineHandlers()
            try hapticEngine?.start()
            engineState = .running
        } catch {
            engineState = .error(error)
            throw HapticNavigationError.playbackFailed(error)
        }
    }
    
    func playTurnLeftPattern() async throws {
        try await playPattern(.leftTurn)
    }
    
    func playTurnRightPattern() async throws {
        try await playPattern(.rightTurn)
    }
    
    func playContinueStraightPattern() async throws {
        try await playPattern(.continueStraight)
    }
    
    func playArrivalPattern() async throws {
        try await playPattern(.arrival)
    }
    
    func stopAllHaptics() {
        currentPlayer?.stop(atTime: CHHapticTimeImmediate)
        currentPlayer = nil
    }
    
    func resetEngine() throws {
        stopAllHaptics()
        hapticEngine?.stop()
        hapticEngine = nil
        engineState = .notInitialized
        try initializeHapticEngine()
    }
    
    // MARK: - Private Methods
    
    private func setupEngineHandlers() {
        hapticEngine?.stoppedHandler = { [weak self] reason in
            Task { @MainActor in
                self?.engineState = .stopped
                print("Haptic engine stopped: \(reason)")
            }
        }
        
        hapticEngine?.resetHandler = { [weak self] in
            Task { @MainActor in
                do {
                    try self?.resetEngine()
                } catch {
                    self?.engineState = .error(error)
                    print("Failed to reset haptic engine: \(error)")
                }
            }
        }
    }
    
    private func playPattern(_ pattern: HapticPattern) async throws {
        guard isHapticModeEnabled else { return }
        
        guard let engine = hapticEngine else {
            throw HapticNavigationError.engineNotInitialized
        }
        
        guard case .running = engineState else {
            throw HapticNavigationError.engineNotInitialized
        }
        
        do {
            // Stop any currently playing pattern
            stopAllHaptics()
            
            // Create haptic pattern
            let hapticPattern = try CHHapticPattern(events: pattern.events, parameters: [])
            
            // Create player
            currentPlayer = try engine.makePlayer(with: hapticPattern)
            
            // Play pattern
            try currentPlayer?.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            engineState = .error(error)
            throw HapticNavigationError.playbackFailed(error)
        }
    }
}

// MARK: - Fallback Implementation for Testing
class MockHapticNavigationService: HapticNavigationServiceProtocol {
    @Published var isHapticModeEnabled: Bool = false
    @Published var engineState: HapticEngineState = .notInitialized
    
    var isHapticCapable: Bool = false
    private var playedPatterns: [String] = []
    
    func initializeHapticEngine() throws {
        engineState = .running
    }
    
    func playTurnLeftPattern() async throws {
        playedPatterns.append("leftTurn")
    }
    
    func playTurnRightPattern() async throws {
        playedPatterns.append("rightTurn")
    }
    
    func playContinueStraightPattern() async throws {
        playedPatterns.append("continueStraight")
    }
    
    func playArrivalPattern() async throws {
        playedPatterns.append("arrival")
    }
    
    func stopAllHaptics() {
        playedPatterns.removeAll()
    }
    
    func resetEngine() throws {
        engineState = .running
        playedPatterns.removeAll()
    }
    
    // Test helper
    func getPlayedPatterns() -> [String] {
        return playedPatterns
    }
}