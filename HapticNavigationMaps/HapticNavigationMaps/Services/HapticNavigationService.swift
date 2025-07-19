import Foundation
import CoreHaptics
import Combine
import UIKit
import AVFoundation

// MARK: - Haptic Fallback Delegate

protocol HapticFallbackDelegate: AnyObject {
    func hapticFeedbackUnavailable(pattern: HapticPattern, reason: HapticNavigationError)
    func playAudioFallback(for pattern: HapticPattern)
    func showVisualFallback(for pattern: HapticPattern)
}

@MainActor
class HapticNavigationService: HapticNavigationServiceProtocol {
    @Published var isHapticModeEnabled: Bool = false
    @Published var engineState: HapticEngineState = .notInitialized
    
    weak var fallbackDelegate: HapticFallbackDelegate?
    
    private var hapticEngine: CHHapticEngine?
    private var currentPlayer: CHHapticPatternPlayer?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var navigationBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isNavigationActive: Bool = false
    private var appStateObserver: NSObjectProtocol?
    
    // Enhanced error tracking
    private var consecutiveFailureCount: Int = 0
    private let maxConsecutiveFailures: Int = 3
    private var lastFailureTime: Date?
    private let failureCooldownPeriod: TimeInterval = 10.0
    
    // Audio fallback support
    nonisolated(unsafe) private var audioEngine: AVAudioEngine?
    nonisolated(unsafe) private var audioPlayerNode: AVAudioPlayerNode?
    private var isAudioFallbackEnabled: Bool = true
    
    var isHapticCapable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    init() {
        // Only enable haptic mode if device supports it
        self.isHapticModeEnabled = isHapticCapable
        setupBackgroundSupport()
        setupAudioFallback()
    }
    
    deinit {
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // End background tasks without async calls in deinit
        if navigationBackgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(navigationBackgroundTask)
            navigationBackgroundTask = .invalid
        }
        
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        
        cleanupAudioEngine()
    }
    
    func initializeHapticEngine() throws {
        guard isHapticCapable else {
            throw HapticNavigationError.engineNotAvailable
        }
        
        // Check if we're in a failure cooldown period
        if let lastFailure = lastFailureTime,
           Date().timeIntervalSince(lastFailure) < failureCooldownPeriod {
            throw HapticNavigationError.engineNotInitialized
        }
        
        engineState = .initializing
        
        do {
            hapticEngine = try CHHapticEngine()
            setupEngineHandlers()
            try hapticEngine?.start()
            engineState = .running
            
            // Reset failure count on successful initialization
            consecutiveFailureCount = 0
            lastFailureTime = nil
            
        } catch {
            consecutiveFailureCount += 1
            lastFailureTime = Date()
            engineState = .error(error)
            
            // If we've hit too many failures, disable haptic mode temporarily
            if consecutiveFailureCount >= maxConsecutiveFailures {
                isHapticModeEnabled = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("HapticEngineFailedPermanently"),
                    object: nil,
                    userInfo: ["error": error]
                )
            }
            
            throw HapticNavigationError.playbackFailed(error)
        }
    }
    
    func playTurnLeftPattern() async throws {
        try await playPatternWithFallback(.leftTurn)
    }
    
    func playTurnRightPattern() async throws {
        try await playPatternWithFallback(.rightTurn)
    }
    
    func playContinueStraightPattern() async throws {
        try await playPatternWithFallback(.continueStraight)
    }
    
    func playArrivalPattern() async throws {
        try await playPatternWithFallback(.arrival)
    }
    
    func stopAllHaptics() {
        do {
            try currentPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error stopping haptic player: \(error)")
        }
        currentPlayer = nil
        
        // Stop audio fallback as well
        stopAudioFallback()
        
        // End any active background task
        endBackgroundTaskIfNeeded()
    }
    
    func resetEngine() throws {
        stopAllHaptics()
        hapticEngine?.stop()
        hapticEngine = nil
        engineState = .notInitialized
        
        // Ensure background task is cleaned up
        endBackgroundTaskIfNeeded()
        
        try initializeHapticEngine()
    }
    
    // MARK: - Enhanced Pattern Playback with Fallback
    
    private func playPatternWithFallback(_ pattern: HapticPattern) async throws {
        guard isHapticModeEnabled else {
            // If haptic mode is disabled, immediately use fallback
            await handleHapticFallback(pattern: pattern, error: .engineNotAvailable)
            return
        }
        
        do {
            try await playPattern(pattern)
        } catch let error as HapticNavigationError {
            // Handle haptic failure with fallback
            await handleHapticFallback(pattern: pattern, error: error)
            throw error
        } catch {
            let hapticError = HapticNavigationError.playbackFailed(error)
            await handleHapticFallback(pattern: pattern, error: hapticError)
            throw hapticError
        }
    }
    
    private func handleHapticFallback(pattern: HapticPattern, error: HapticNavigationError) async {
        // Notify delegate about the fallback
        fallbackDelegate?.hapticFeedbackUnavailable(pattern: pattern, reason: error)
        
        // Try audio fallback first
        if isAudioFallbackEnabled {
            await playAudioFallback(for: pattern)
        } else {
            // Show visual fallback
            fallbackDelegate?.showVisualFallback(for: pattern)
            await showVisualFallback(for: pattern)
        }
        
        // Post notification for UI to handle the fallback
        NotificationCenter.default.post(
            name: NSNotification.Name("HapticFallbackActivated"),
            object: nil,
            userInfo: [
                "pattern": pattern.rawValue,
                "error": error.localizedDescription
            ]
        )
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
            // Handle background haptic playback
            beginBackgroundTaskIfNeeded()
            
            // Stop any currently playing pattern
            stopAllHaptics()
            
            // Create haptic pattern
            let hapticPattern = try CHHapticPattern(events: pattern.events, parameters: [])
            
            // Create player
            currentPlayer = try engine.makePlayer(with: hapticPattern)
            
            // Play pattern
            try currentPlayer?.start(atTime: CHHapticTimeImmediate)
            
            // Schedule background task completion after pattern duration
            scheduleBackgroundTaskCompletion(after: pattern.duration)
            
        } catch {
            endBackgroundTaskIfNeeded()
            engineState = .error(error)
            throw HapticNavigationError.playbackFailed(error)
        }
    }
    
    /// Begin background task for haptic playback
    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier == .invalid else { return }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "HapticPlayback") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }
    
    /// End background task after haptic playback
    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
    
    /// Schedule background task completion after pattern completes
    private func scheduleBackgroundTaskCompletion(after duration: TimeInterval) {
        Task {
            // Wait for pattern to complete, plus a small buffer
            try await Task.sleep(nanoseconds: UInt64((duration + 0.5) * 1_000_000_000))
            await MainActor.run {
                endBackgroundTaskIfNeeded()
            }
        }
    }
    
    // MARK: - Background Navigation Support
    
    private func setupBackgroundSupport() {
        // Monitor app state changes for navigation background tasks
        appStateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
    }
    
    /// Start continuous background task for navigation
    func startNavigationBackgroundTask() {
        guard !isNavigationActive else { return }
        
        isNavigationActive = true
        beginNavigationBackgroundTask()
    }
    
    /// Stop continuous background task for navigation
    func stopNavigationBackgroundTask() {
        isNavigationActive = false
        endNavigationBackgroundTask()
    }
    
    private func beginNavigationBackgroundTask() {
        guard navigationBackgroundTask == .invalid else { return }
        
        navigationBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "NavigationHaptics") { [weak self] in
            // When background time expires, restart the task if navigation is still active
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
    }
    
    private func endNavigationBackgroundTask() {
        guard navigationBackgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(navigationBackgroundTask)
        navigationBackgroundTask = .invalid
    }
    
    private func handleAppDidEnterBackground() {
        // Start navigation background task if haptic navigation is active
        if isHapticModeEnabled && isNavigationActive {
            beginNavigationBackgroundTask()
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        // End current task
        endNavigationBackgroundTask()
        
        // Restart background task if navigation is still active
        if isNavigationActive {
            beginNavigationBackgroundTask()
        }
    }
    
    // MARK: - Audio Fallback Support
    
    private func setupAudioFallback() {
        // Initialize audio engine and player
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = audioPlayerNode else {
            print("Audio fallback not available.")
            isAudioFallbackEnabled = false
            return
        }
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine for fallback: \(error)")
            isAudioFallbackEnabled = false
        }
    }
    
    private func playAudioFallback(for pattern: HapticPattern) async {
        guard isAudioFallbackEnabled else { 
            await showVisualFallback(for: pattern)
            return 
        }
        
        // Play different audio tones for different navigation patterns
        let frequency = pattern.audioFrequency
        let duration = pattern.duration
        
        do {
            try await playTone(frequency: frequency, duration: duration)
            fallbackDelegate?.playAudioFallback(for: pattern)
        } catch {
            print("Failed to play audio fallback: \(error)")
            await showVisualFallback(for: pattern)
        }
    }
    
    private func playTone(frequency: Float, duration: TimeInterval) async throws {
        guard let engine = audioEngine, let player = audioPlayerNode else {
            throw HapticNavigationError.playbackFailed(NSError(domain: "AudioFallback", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not available"]))
        }
        
        let sampleRate = Float(engine.outputNode.outputFormat(forBus: 0).sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * Float(duration))
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.outputNode.outputFormat(forBus: 0), frameCapacity: frameCount) else {
            throw HapticNavigationError.playbackFailed(NSError(domain: "AudioFallback", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"]))
        }
        
        buffer.frameLength = frameCount
        
        // Generate sine wave tone
        let angleDelta = Float(2.0 * Double.pi * Double(frequency) / Double(sampleRate))
        var angle: Float = 0
        
        for frame in 0..<Int(frameCount) {
            let value = sin(angle) * 0.3 // 30% volume
            buffer.floatChannelData?.pointee[frame] = value
            if buffer.format.channelCount == 2 {
                buffer.floatChannelData?.advanced(by: 1).pointee[frame] = value
            }
            angle += angleDelta
            if angle > Float(2.0 * Double.pi) {
                angle -= Float(2.0 * Double.pi)
            }
        }
        
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
        
        // Wait for the tone to complete
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    private func stopAudioFallback() {
        audioPlayerNode?.stop()
    }
    
    private func showVisualFallback(for pattern: HapticPattern) async {
        // This is a placeholder for a visual fallback mechanism.
        // In a real app, you might present a UIAlertController or show a custom view.
        print("Visual fallback for pattern: \(pattern.rawValue)")
    }
    
    nonisolated private func cleanupAudioEngine() {
        audioEngine?.stop()
        audioEngine = nil
        audioPlayerNode = nil
    }
}