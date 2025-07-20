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
    private let backgroundTaskManager = BackgroundTaskManager.shared
    private var isNavigationActive: Bool = false
    private var appStateObserver: NSObjectProtocol?
    
    // Enhanced error tracking
    private var consecutiveFailureCount: Int = 0
    private let maxConsecutiveFailures: Int = 3
    private var lastFailureTime: Date?
    private let failureCooldownPeriod: TimeInterval = 10.0
    
    // Haptic pattern caching for performance optimization
    private var cachedPatterns: [NavigationPatternType: CHHapticPattern] = [:]
    private var cachedPlayers: [NavigationPatternType: CHHapticPatternPlayer] = [:]
    private var patternCacheInitialized: Bool = false
    private let maxCacheSize: Int = 10
    
    // Performance monitoring
    private var patternCreationCount: Int = 0
    private var patternCacheHits: Int = 0
    private var lastPerformanceReset: Date = Date()
    @Published var patternCacheHitRate: Double = 0.0
    
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
        
        // Set up accessibility service as fallback delegate
        // Note: AccessibilityService will be connected when available
        self.fallbackDelegate = nil
    }
    
    deinit {
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Clear pattern cache to free memory
        Task { @MainActor in
            clearPatternCache()
        }
        
        // End background tasks
        Task { @MainActor in
            backgroundTaskManager.endTask(.hapticPlayback)
            backgroundTaskManager.endTask(.navigation)
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
            
            // Preload haptic patterns for better performance
            try preloadHapticPatterns()
            
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
        Task { @MainActor in
            clearPatternCache()
        }
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
    
    // MARK: - Haptic Pattern Caching
    
    /// Preload all navigation patterns into cache for better performance
    private func preloadHapticPatterns() throws {
        guard let engine = hapticEngine else {
            throw HapticNavigationError.engineNotInitialized
        }
        
        let patterns: [NavigationPatternType: HapticPattern] = [
            .leftTurn: .leftTurn,
            .rightTurn: .rightTurn,
            .continueStraight: .continueStraight,
            .arrival: .arrival
        ]
        
        for (patternType, hapticPattern) in patterns {
            do {
                let chPattern = try CHHapticPattern(events: hapticPattern.events, parameters: [])
                let player = try engine.makePlayer(with: chPattern)
                
                cachedPatterns[patternType] = chPattern
                cachedPlayers[patternType] = player
                
                print("Preloaded pattern: \(patternType.rawValue)")
            } catch {
                print("Failed to preload pattern \(patternType.rawValue): \(error)")
                // Continue with other patterns even if one fails
            }
        }
        
        patternCacheInitialized = true
        print("Haptic pattern cache initialized with \(cachedPatterns.count) patterns")
    }
    
    /// Get cached pattern player or create new one if not cached
    private func getCachedPlayer(for patternType: NavigationPatternType) throws -> CHHapticPatternPlayer {
        if let cachedPlayer = cachedPlayers[patternType] {
            patternCacheHits += 1
            return cachedPlayer
        }
        
        // Pattern not cached, create it
        patternCreationCount += 1
        return try createPatternPlayer(for: patternType)
    }
    
    /// Create a new pattern player for the given pattern type
    private func createPatternPlayer(for patternType: NavigationPatternType) throws -> CHHapticPatternPlayer {
        guard let engine = hapticEngine else {
            throw HapticNavigationError.engineNotInitialized
        }
        
        let hapticPattern = getHapticPattern(for: patternType)
        let chPattern = try CHHapticPattern(events: hapticPattern.events, parameters: [])
        let player = try engine.makePlayer(with: chPattern)
        
        // Add to cache if there's space
        if cachedPlayers.count < maxCacheSize {
            cachedPatterns[patternType] = chPattern
            cachedPlayers[patternType] = player
        }
        
        return player
    }
    
    /// Get HapticPattern for a given pattern type
    private func getHapticPattern(for patternType: NavigationPatternType) -> HapticPattern {
        switch patternType {
        case .leftTurn:
            return .leftTurn
        case .rightTurn:
            return .rightTurn
        case .continueStraight:
            return .continueStraight
        case .arrival:
            return .arrival
        }
    }
    
    /// Clear pattern cache and release memory
    private func clearPatternCache() {
        cachedPatterns.removeAll()
        cachedPlayers.removeAll()
        patternCacheInitialized = false
        print("Haptic pattern cache cleared")
    }
    
    /// Update performance metrics for pattern caching
    private func updateCachePerformanceMetrics() {
        let totalOperations = patternCreationCount + patternCacheHits
        if totalOperations > 0 {
            patternCacheHitRate = Double(patternCacheHits) / Double(totalOperations)
        }
        
        // Reset counters periodically
        if Date().timeIntervalSince(lastPerformanceReset) > 300.0 { // 5 minutes
            patternCreationCount = 0
            patternCacheHits = 0
            lastPerformanceReset = Date()
            print("Cache hit rate: \(String(format: "%.2f", patternCacheHitRate * 100))%")
        }
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
        
        guard hapticEngine != nil else {
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
            
            // Get cached player or create new one
            currentPlayer = try getCachedPlayer(for: pattern.patternType)
            
            // Update performance metrics
            updateCachePerformanceMetrics()
            
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
        let _ = backgroundTaskManager.beginTask(.hapticPlayback)
    }
    
    /// End background task after haptic playback
    private func endBackgroundTaskIfNeeded() {
        Task { @MainActor in
            backgroundTaskManager.endTask(.hapticPlayback)
        }
    }
    
    /// Handle haptic playback task expiration
    private func handleHapticPlaybackExpiration() {
        print("Haptic playback background task expired")
        stopAllHaptics()
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
        let _ = backgroundTaskManager.beginTask(.navigation)
    }
    
    /// Stop continuous background task for navigation
    func stopNavigationBackgroundTask() {
        isNavigationActive = false
        Task { @MainActor in
            backgroundTaskManager.endTask(.navigation)
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Start navigation background task if haptic navigation is active
        if isHapticModeEnabled && isNavigationActive {
            let _ = backgroundTaskManager.beginTask(.navigation)
        }
    }
    
    private func handleNavigationTaskExpiration() {
        print("Navigation background task expired")
        
        // If navigation is still active, try to restart the task
        if isNavigationActive {
            // Small delay before restart to avoid rapid cycling
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                if let self = self, self.isNavigationActive {
                    let _ = self.backgroundTaskManager.beginTask(.navigation)
                }
            }
        }
    }
    
    // MARK: - Audio Fallback Support
    
    private func setupAudioFallback() {
        do {
            // Configure audio session first
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Initialize audio engine and player
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let player = audioPlayerNode else {
                print("Audio fallback not available.")
                isAudioFallbackEnabled = false
                return
            }
            
            // Use explicit audio format to avoid converter issues
            let outputFormat = engine.outputNode.outputFormat(forBus: 0)
            let playerFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: outputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )
            
            guard let format = playerFormat else {
                print("Could not create audio format for fallback")
                isAudioFallbackEnabled = false
                return
            }
            
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            
            try engine.start()
            
        } catch {
            print("Failed to setup audio fallback: \(error)")
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
        
        // Validate input parameters
        guard frequency > 0, frequency < 20000, duration > 0, duration < 10 else {
            throw HapticNavigationError.playbackFailed(NSError(domain: "AudioFallback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid audio parameters"]))
        }
        
        // Use consistent format
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)
        let frameCount = AVAudioFrameCount(sampleRate * Float(duration))
        
        // Create buffer with mono format to avoid converter issues
        let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputFormat.sampleRate,
            channels: 1,
            interleaved: false
        )
        
        guard let format = monoFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw HapticNavigationError.playbackFailed(NSError(domain: "AudioFallback", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"]))
        }
        
        buffer.frameLength = frameCount
        
        // Generate sine wave tone with bounds checking
        let angleDelta = Float(2.0 * Double.pi * Double(frequency) / Double(sampleRate))
        var angle: Float = 0
        
        guard let channelData = buffer.floatChannelData?[0] else {
            throw HapticNavigationError.playbackFailed(NSError(domain: "AudioFallback", code: -4, userInfo: [NSLocalizedDescriptionKey: "Could not access audio buffer data"]))
        }
        
        for frame in 0..<Int(frameCount) {
            let value = sin(angle) * 0.3 // 30% volume
            channelData[frame] = value
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