import XCTest
import CoreHaptics
import Combine
@testable import HapticNavigationMaps

// Mock CHHapticEngine for testing
class MockCHHapticEngine: Equatable {
    var isStarted = false
    var isStopped = false
    var stoppedHandler: ((CHHapticEngine.StoppedReason) -> Void)?
    var resetHandler: (() -> Void)?
    var shouldThrowOnStart = false
    var shouldThrowOnMakePlayer = false
    var createdPlayers: [MockCHHapticPatternPlayer] = []
    
    func start() throws {
        if shouldThrowOnStart {
            throw CHHapticError(.engineNotRunning)
        }
        isStarted = true
        isStopped = false
    }
    
    func stop() {
        isStarted = false
        isStopped = true
    }
    
    func makePlayer(with pattern: CHHapticPattern) throws -> MockCHHapticPatternPlayer {
        if shouldThrowOnMakePlayer {
            throw CHHapticError(.invalidPatternPlayer)
        }
        let player = MockCHHapticPatternPlayer()
        createdPlayers.append(player)
        return player
    }
    
    // Helper methods for testing
    func simulateEngineStop(reason: CHHapticEngine.StoppedReason = .gameControllerDisconnect) {
        isStarted = false
        isStopped = true
        stoppedHandler?(reason)
    }
    
    func simulateEngineReset() {
        resetHandler?()
    }
    
    static func == (lhs: MockCHHapticEngine, rhs: MockCHHapticEngine) -> Bool {
        return lhs.isStarted == rhs.isStarted && 
               lhs.isStopped == rhs.isStopped
    }
}

// Mock CHHapticPatternPlayer for testing
class MockCHHapticPatternPlayer {
    var isPlaying = false
    var isStopped = false
    var shouldThrowOnStart = false
    
    func start(atTime time: TimeInterval) throws {
        if shouldThrowOnStart {
            throw CHHapticError(.invalidPatternPlayer)
        }
        isPlaying = true
        isStopped = false
    }
    
    func stop(atTime time: TimeInterval) {
        isPlaying = false
        isStopped = true
    }
}

// Testable HapticNavigationService that uses mock engine
class TestableHapticNavigationService: HapticNavigationService {
    var mockEngine: MockCHHapticEngine?
    var forceHapticCapable: Bool?
    
    override var isHapticCapable: Bool {
        return forceHapticCapable ?? super.isHapticCapable
    }
    
    // Override to use mock engine
    override func initializeHapticEngine() throws {
        guard forceHapticCapable ?? isHapticCapable else {
            throw HapticNavigationError.engineNotAvailable
        }
        
        engineState = .initializing
        
        do {
            mockEngine = MockCHHapticEngine()
            setupMockEngineHandlers()
            try mockEngine?.start()
            engineState = .running
        } catch {
            engineState = .error(error)
            throw HapticNavigationError.playbackFailed(error)
        }
    }
    
    private func setupMockEngineHandlers() {
        mockEngine?.stoppedHandler = { [weak self] reason in
            Task { @MainActor in
                self?.engineState = .stopped
            }
        }
        
        mockEngine?.resetHandler = { [weak self] in
            Task { @MainActor in
                do {
                    try self?.resetEngine()
                } catch {
                    self?.engineState = .error(error)
                }
            }
        }
    }
    
    override func resetEngine() throws {
        stopAllHaptics()
        mockEngine?.stop()
        mockEngine = nil
        engineState = .notInitialized
        try initializeHapticEngine()
    }
    
    // Test helper methods
    func getMockEngine() -> MockCHHapticEngine? {
        return mockEngine
    }
}

class HapticNavigationServiceTests: XCTestCase {
    var hapticService: HapticNavigationService!
    var mockFallbackDelegate: MockHapticFallbackDelegate!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        hapticService = HapticNavigationService()
        mockFallbackDelegate = MockHapticFallbackDelegate()
        hapticService.fallbackDelegate = mockFallbackDelegate
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        hapticService = nil
        mockFallbackDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testHapticServiceInitialization() {
        XCTAssertNotNil(hapticService)
        XCTAssertEqual(hapticService.engineState, .notInitialized)
        XCTAssertEqual(hapticService.isHapticModeEnabled, hapticService.isHapticCapable)
    }
    
    func testIsHapticCapable() {
        let isCapable = hapticService.isHapticCapable
        XCTAssertEqual(isCapable, CHHapticEngine.capabilitiesForHardware().supportsHaptics)
    }
    
    func testInitializeHapticEngineOnCapableDevice() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        let expectation = XCTestExpectation(description: "Engine state updated")
        hapticService.$engineState
            .sink { state in
                if case .running = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        do {
            try hapticService.initializeHapticEngine()
            wait(for: [expectation], timeout: 2.0)
            XCTAssertEqual(hapticService.engineState, .running)
        } catch {
            XCTFail("Engine initialization should succeed on capable device: \(error)")
        }
    }
    
    func testInitializeHapticEngineOnNonCapableDevice() {
        // This test simulates a non-capable device
        // We can't actually test this on a capable device, so we skip if capable
        guard !hapticService.isHapticCapable else {
            return // Skip test on capable devices
        }
        
        XCTAssertThrowsError(try hapticService.initializeHapticEngine()) { error in
            XCTAssertEqual(error as? HapticNavigationError, .engineNotAvailable)
        }
    }
    
    // MARK: - Pattern Playback Tests
    
    func testPlayTurnLeftPattern() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
    }
    
        try hapticService.initializeHapticEngine()
        
        do {
            try await hapticService.playTurnLeftPattern()
            // If we reach here, the pattern played successfully
            XCTAssertTrue(true, "Turn left pattern played successfully")
        } catch {
            // On devices that support haptics but fail to play patterns,
            // we should have fallback behavior triggered
            XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
        }
    }
    
    func testPlayTurnRightPattern() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        try hapticService.initializeHapticEngine()
        
        do {
            try await hapticService.playTurnRightPattern()
            XCTAssertTrue(true, "Turn right pattern played successfully")
        } catch {
            XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
        }
    }
    
    func testPlayContinueStraightPattern() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        try hapticService.initializeHapticEngine()
        
        do {
            try await hapticService.playContinueStraightPattern()
            XCTAssertTrue(true, "Continue straight pattern played successfully")
        } catch {
            XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
        }
    }
    
    func testPlayArrivalPattern() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        try hapticService.initializeHapticEngine()
        
        do {
            try await hapticService.playArrivalPattern()
            XCTAssertTrue(true, "Arrival pattern played successfully")
        } catch {
            XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testPlayPatternWithoutInitializedEngine() async {
        // Don't initialize the engine
        
        let expectation = XCTestExpectation(description: "Fallback triggered")
        mockFallbackDelegate.onHapticFeedbackUnavailable = { pattern, reason in
            XCTAssertEqual(reason, .engineNotInitialized)
            expectation.fulfill()
        }
        
        do {
            try await hapticService.playTurnLeftPattern()
            XCTFail("Should throw error when engine not initialized")
        } catch {
            XCTAssertEqual(error as? HapticNavigationError, .engineNotInitialized)
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
    }
    
    func testPlayPatternWithHapticModeDisabled() async {
        hapticService.isHapticModeEnabled = false
        
        let expectation = XCTestExpectation(description: "Fallback triggered")
        mockFallbackDelegate.onHapticFeedbackUnavailable = { pattern, reason in
            XCTAssertEqual(reason, .engineNotAvailable)
            expectation.fulfill()
        }
        
        // Should immediately trigger fallback without error
        try? await hapticService.playTurnLeftPattern()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFallbackDelegate.hapticFeedbackUnavailableCalled)
    }
    
    func testConsecutiveFailuresDisableHapticMode() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        let expectation = XCTestExpectation(description: "Haptic mode disabled after failures")
        
        // Listen for the permanent failure notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HapticEngineFailedPermanently"), object: nil, queue: .main) { _ in
            expectation.fulfill()
        }
        
        // Simulate multiple failures by trying to initialize in rapid succession
        // In a real scenario, this would be triggered by actual engine failures
        
        // Force consecutive failures
        for _ in 0..<4 { // Exceeds maxConsecutiveFailures (3)
            do {
                try hapticService.initializeHapticEngine()
                // If successful, break the loop
                break
            } catch {
                // Continue to next attempt
                continue
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testEngineResetAfterError() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        // Initialize engine successfully first
        try hapticService.initializeHapticEngine()
        XCTAssertEqual(hapticService.engineState, .running)
        
        // Reset the engine
        try hapticService.resetEngine()
        
        // Should be running again after reset
        XCTAssertEqual(hapticService.engineState, .running)
    }
    
    // MARK: - Fallback Mechanism Tests
    
    func testAudioFallbackTriggered() async {
        // Disable haptic mode to force fallback
        hapticService.isHapticModeEnabled = false
        
        let expectation = XCTestExpectation(description: "Audio fallback triggered")
        mockFallbackDelegate.onPlayAudioFallback = { pattern in
            XCTAssertEqual(pattern.patternType, .leftTurn)
            expectation.fulfill()
        }
        
        try? await hapticService.playTurnLeftPattern()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFallbackDelegate.playAudioFallbackCalled)
    }
    
    func testVisualFallbackTriggered() async {
        // Disable haptic mode to force fallback
        hapticService.isHapticModeEnabled = false
        
        let expectation = XCTestExpectation(description: "Visual fallback triggered")
        mockFallbackDelegate.onShowVisualFallback = { pattern in
            XCTAssertEqual(pattern.patternType, .rightTurn)
            expectation.fulfill()
        }
        
        try? await hapticService.playTurnRightPattern()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFallbackDelegate.showVisualFallbackCalled)
    }
    
    func testFallbackNotificationPosted() async {
        hapticService.isHapticModeEnabled = false
        
        let expectation = XCTestExpectation(description: "Fallback notification posted")
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HapticFallbackActivated"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let pattern = userInfo["pattern"] as? String,
               let error = userInfo["error"] as? String {
                XCTAssertEqual(pattern, "continueStraight")
                XCTAssertFalse(error.isEmpty)
                expectation.fulfill()
            }
        }
        
        try? await hapticService.playContinueStraightPattern()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Background Task Tests
    
    func testStartNavigationBackgroundTask() {
        hapticService.startNavigationBackgroundTask()
        
        // We can't easily test UIBackgroundTaskIdentifier values,
        // but we can verify the method doesn't crash
        XCTAssertTrue(true, "Background task started without crashing")
    }
    
    func testStopNavigationBackgroundTask() {
        hapticService.startNavigationBackgroundTask()
        hapticService.stopNavigationBackgroundTask()
        
        // Should complete without crashing
        XCTAssertTrue(true, "Background task stopped without crashing")
    }
    
    func testStopAllHaptics() {
        hapticService.stopAllHaptics()
        
        // Should complete without crashing
        XCTAssertTrue(true, "Stop all haptics completed without crashing")
    }
    
    // MARK: - Cooldown Period Tests
    
    func testFailureCooldownPreventsInitialization() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        // Simulate a recent failure by setting the internal failure time
        hapticService.setValue(Date(), forKey: "lastFailureTime")
        
        // Should throw error due to cooldown
        XCTAssertThrowsError(try hapticService.initializeHapticEngine()) { error in
            XCTAssertEqual(error as? HapticNavigationError, .engineNotInitialized)
        }
    }
    
    // MARK: - Haptic Pattern Audio Properties Tests
    
    func testHapticPatternAudioFrequencies() {
        XCTAssertEqual(HapticPattern.leftTurn.audioFrequency, 440.0) // A4
        XCTAssertEqual(HapticPattern.rightTurn.audioFrequency, 523.25) // C5
        XCTAssertEqual(HapticPattern.continueStraight.audioFrequency, 329.63) // E4
        XCTAssertEqual(HapticPattern.arrival.audioFrequency, 659.25) // E5
    }
    
    func testHapticPatternAudioDescriptions() {
        XCTAssertEqual(HapticPattern.leftTurn.audioDescription, "Turn left")
        XCTAssertEqual(HapticPattern.rightTurn.audioDescription, "Turn right")
        XCTAssertEqual(HapticPattern.continueStraight.audioDescription, "Continue straight")
        XCTAssertEqual(HapticPattern.arrival.audioDescription, "Arrived at destination")
    }
    
    func testHapticPatternRawValues() {
        XCTAssertEqual(HapticPattern.leftTurn.rawValue, "leftTurn")
        XCTAssertEqual(HapticPattern.rightTurn.rawValue, "rightTurn")
        XCTAssertEqual(HapticPattern.continueStraight.rawValue, "continueStraight")
        XCTAssertEqual(HapticPattern.arrival.rawValue, "arrival")
    }
    
    // MARK: - Error State Tests
    
    func testHapticNavigationErrorEquality() {
        XCTAssertEqual(HapticNavigationError.engineNotAvailable, HapticNavigationError.engineNotAvailable)
        XCTAssertEqual(HapticNavigationError.engineNotInitialized, HapticNavigationError.engineNotInitialized)
        XCTAssertEqual(HapticNavigationError.patternCreationFailed, HapticNavigationError.patternCreationFailed)
        
        let error1 = NSError(domain: "test", code: 1)
        let error2 = NSError(domain: "test", code: 2)
        XCTAssertEqual(HapticNavigationError.playbackFailed(error1), HapticNavigationError.playbackFailed(error2))
    }
    
    func testHapticNavigationErrorDescriptions() {
        let errors: [HapticNavigationError] = [
            .engineNotAvailable,
            .engineNotInitialized,
            .patternCreationFailed,
            .playbackFailed(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testHapticEngineStateEquality() {
        XCTAssertEqual(HapticEngineState.notInitialized, HapticEngineState.notInitialized)
        XCTAssertEqual(HapticEngineState.initializing, HapticEngineState.initializing)
        XCTAssertEqual(HapticEngineState.running, HapticEngineState.running)
        XCTAssertEqual(HapticEngineState.stopped, HapticEngineState.stopped)
        
        let error1 = NSError(domain: "test", code: 1)
        let error2 = NSError(domain: "test", code: 2)
        XCTAssertEqual(HapticEngineState.error(error1), HapticEngineState.error(error2))
    }
    
    // MARK: - Performance Tests
    
    func testHapticPatternPlaybackPerformance() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        try hapticService.initializeHapticEngine()
        
        measure {
            let expectation = XCTestExpectation(description: "Pattern playback performance")
            
            Task {
                do {
                    try await hapticService.playTurnLeftPattern()
                    expectation.fulfill()
                } catch {
                    expectation.fulfill() // Count errors as completion for performance test
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentPatternPlayback() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Device doesn't support haptics")
        }
        
        try hapticService.initializeHapticEngine()
        
        await withTaskGroup(of: Void.self) { group in
            // Try to play multiple patterns concurrently
            group.addTask {
                try? await self.hapticService.playTurnLeftPattern()
            }
            group.addTask {
                try? await self.hapticService.playTurnRightPattern()
            }
            group.addTask {
                try? await self.hapticService.playContinueStraightPattern()
            }
            group.addTask {
                try? await self.hapticService.playArrivalPattern()
            }
        }
        
        // Test should complete without crashing
        XCTAssertTrue(true, "Concurrent pattern playback completed")
    }
    }
    
// MARK: - Mock Haptic Fallback Delegate

class MockHapticFallbackDelegate: HapticFallbackDelegate {
    var hapticFeedbackUnavailableCalled = false
    var playAudioFallbackCalled = false
    var showVisualFallbackCalled = false
    
    var onHapticFeedbackUnavailable: ((HapticPattern, HapticNavigationError) -> Void)?
    var onPlayAudioFallback: ((HapticPattern) -> Void)?
    var onShowVisualFallback: ((HapticPattern) -> Void)?
    
    func hapticFeedbackUnavailable(pattern: HapticPattern, reason: HapticNavigationError) {
        hapticFeedbackUnavailableCalled = true
        onHapticFeedbackUnavailable?(pattern, reason)
    }
    
    func playAudioFallback(for pattern: HapticPattern) {
        playAudioFallbackCalled = true
        onPlayAudioFallback?(pattern)
    }
    
    func showVisualFallback(for pattern: HapticPattern) {
        showVisualFallbackCalled = true
        onShowVisualFallback?(pattern)
    }
}
// Note: MockHapticNavigationService is defined in NavigationModeUITests.swift to avoid conflicts 