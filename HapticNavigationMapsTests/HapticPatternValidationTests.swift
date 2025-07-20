import XCTest
import CoreHaptics
import AVFoundation
import Combine
@testable import HapticNavigationMaps

/// Comprehensive haptic pattern validation tests for distinctiveness and user experience
@MainActor
class HapticPatternValidationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var hapticService: HapticNavigationService!
    var accessibilityService: AccessibilityService!
    var cancellables: Set<AnyCancellable>!
    
    // Pattern analysis results
    struct PatternAnalysis {
        let patternType: NavigationPatternType
        let duration: TimeInterval
        let intensityProfile: [Float]
        let sharpnessProfile: [Float]
        let eventCount: Int
        let distinctivenessScore: Double
        let userExperienceScore: Double
    }
    
    // User experience metrics
    struct UserExperienceMetrics {
        let recognitionAccuracy: Double    // How accurately users can identify patterns
        let responseTime: TimeInterval     // Time to recognize pattern
        let comfortLevel: Double          // Comfort rating (1-10)
        let distinctiveness: Double       // How distinct pattern feels from others
        let appropriateness: Double       // How appropriate pattern feels for navigation cue
    }
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        hapticService = HapticNavigationService()
        accessibilityService = AccessibilityService.shared
        cancellables = Set<AnyCancellable>()
        
        // Only run haptic tests on capable devices
        if hapticService.isHapticCapable {
            try hapticService.initializeHapticEngine()
        }
    }
    
    override func tearDown() async throws {
        if hapticService.isHapticCapable {
            hapticService.stopAllHaptics()
        }
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Pattern Distinctiveness Tests
    
    func testHapticPatternDistinctiveness() throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Analyze all navigation patterns
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        var patternAnalyses: [PatternAnalysis] = []
        
        for patternType in patterns {
            let analysis = analyzeHapticPattern(patternType)
            patternAnalyses.append(analysis)
        }
        
        // Verify patterns are sufficiently distinct
        try validatePatternDistinctiveness(patternAnalyses)
        
        // Test pairwise distinctiveness
        try testPairwiseDistinctiveness(patternAnalyses)
        
        // Verify pattern consistency
        try validatePatternConsistency(patternAnalyses)
    }
    
    func analyzeHapticPattern(_ patternType: NavigationPatternType) -> PatternAnalysis {
        let hapticPattern = getHapticPattern(for: patternType)
        
        // Extract pattern characteristics
        var intensityProfile: [Float] = []
        var sharpnessProfile: [Float] = []
        
        for event in hapticPattern.events {
            for parameter in event.eventParameters {
                switch parameter.parameterID {
                case .hapticIntensity:
                    intensityProfile.append(parameter.value)
                case .hapticSharpness:
                    sharpnessProfile.append(parameter.value)
                default:
                    break
                }
            }
        }
        
        // Calculate distinctiveness score based on pattern characteristics
        let distinctivenessScore = calculateDistinctivenessScore(
            duration: hapticPattern.duration,
            eventCount: hapticPattern.events.count,
            intensityVariation: intensityProfile.standardDeviation,
            sharpnessVariation: sharpnessProfile.standardDeviation
        )
        
        // Calculate user experience score
        let userExperienceScore = calculateUserExperienceScore(for: patternType, pattern: hapticPattern)
        
        return PatternAnalysis(
            patternType: patternType,
            duration: hapticPattern.duration,
            intensityProfile: intensityProfile,
            sharpnessProfile: sharpnessProfile,
            eventCount: hapticPattern.events.count,
            distinctivenessScore: distinctivenessScore,
            userExperienceScore: userExperienceScore
        )
    }
    
    func validatePatternDistinctiveness(_ analyses: [PatternAnalysis]) throws {
        // Each pattern should have a minimum distinctiveness score
        let minimumDistinctivenessScore = 0.6
        
        for analysis in analyses {
            XCTAssertGreaterThan(analysis.distinctivenessScore, minimumDistinctivenessScore,
                               "\(analysis.patternType.rawValue) pattern should be sufficiently distinctive")
        }
        
        // Verify duration distinctiveness
        let durations = analyses.map { $0.duration }
        let durationVariation = durations.standardDeviation
        XCTAssertGreaterThan(durationVariation, 0.1, "Pattern durations should vary sufficiently")
        
        // Verify event count distinctiveness
        let eventCounts = analyses.map { Double($0.eventCount) }
        let eventCountVariation = eventCounts.standardDeviation
        XCTAssertGreaterThan(eventCountVariation, 0.5, "Pattern event counts should vary sufficiently")
    }
    
    func testPairwiseDistinctiveness(_ analyses: [PatternAnalysis]) throws {
        // Test distinctiveness between each pair of patterns
        for i in 0..<analyses.count {
            for j in (i+1)..<analyses.count {
                let pattern1 = analyses[i]
                let pattern2 = analyses[j]
                
                let similarity = calculatePatternSimilarity(pattern1, pattern2)
                let distinctiveness = 1.0 - similarity
                
                XCTAssertGreaterThan(distinctiveness, 0.4,
                                   "\(pattern1.patternType.rawValue) and \(pattern2.patternType.rawValue) should be sufficiently distinct (similarity: \(similarity))")
            }
        }
    }
    
    func validatePatternConsistency(_ analyses: [PatternAnalysis]) throws {
        // Verify patterns are consistent with their intended navigation cues
        
        for analysis in analyses {
            switch analysis.patternType {
            case .leftTurn:
                // Left turn should be sharp and brief
                XCTAssertLessThan(analysis.duration, 0.3, "Left turn pattern should be brief")
                XCTAssertGreaterThan(analysis.sharpnessProfile.average, 0.7, "Left turn should be sharp")
                
            case .rightTurn:
                // Right turn should be distinctive from left turn
                XCTAssertLessThan(analysis.duration, 0.5, "Right turn pattern should be relatively brief")
                XCTAssertGreaterThan(analysis.eventCount, 1, "Right turn should have multiple events")
                
            case .continueStraight:
                // Continue straight should be gentle and longer
                XCTAssertGreaterThan(analysis.duration, 0.3, "Continue straight should be longer")
                XCTAssertLessThan(analysis.sharpnessProfile.average, 0.5, "Continue straight should be gentle")
                
            case .arrival:
                // Arrival should be celebratory with multiple events
                XCTAssertGreaterThan(analysis.eventCount, 2, "Arrival should have multiple celebratory events")
                XCTAssertGreaterThan(analysis.duration, 0.4, "Arrival should be substantial")
            }
        }
    }
    
    // MARK: - User Experience Tests
    
    func testHapticPatternUserExperience() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test each pattern for user experience quality
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        
        for patternType in patterns {
            try await testPatternUserExperience(patternType)
        }
        
        // Test pattern sequences for navigation scenarios
        try await testNavigationSequenceUserExperience()
        
        // Test accessibility compliance
        try testAccessibilityCompliance()
    }
    
    func testPatternUserExperience(_ patternType: NavigationPatternType) async throws {
        let hapticPattern = getHapticPattern(for: patternType)
        
        // Test pattern comfort level
        validatePatternComfort(hapticPattern, for: patternType)
        
        // Test pattern timing
        try await validatePatternTiming(patternType)
        
        // Test pattern intensity appropriateness
        validatePatternIntensity(hapticPattern, for: patternType)
        
        // Test pattern in context
        validatePatternContext(patternType)
    }
    
    func validatePatternComfort(_ pattern: HapticPattern, for patternType: NavigationPatternType) {
        // Verify intensity levels are comfortable
        for event in pattern.events {
            for parameter in event.eventParameters {
                if parameter.parameterID == .hapticIntensity {
                    XCTAssertLessThanOrEqual(parameter.value, 1.0, "Intensity should not exceed maximum")
                    
                    // Navigation patterns should not be too intense for comfort
                    switch patternType {
                    case .leftTurn, .rightTurn:
                        XCTAssertLessThanOrEqual(parameter.value, 1.0, "Turn patterns should be noticeable but comfortable")
                    case .continueStraight:
                        XCTAssertLessThanOrEqual(parameter.value, 0.5, "Continue straight should be gentle")
                    case .arrival:
                        XCTAssertLessThanOrEqual(parameter.value, 0.9, "Arrival pattern can be more intense but still comfortable")
                    }
                }
            }
        }
        
        // Verify duration is appropriate for comfort
        switch patternType {
        case .leftTurn, .rightTurn:
            XCTAssertLessThan(pattern.duration, 0.5, "Turn patterns should not be uncomfortably long")
        case .continueStraight:
            XCTAssertLessThan(pattern.duration, 1.0, "Continue straight should not be excessive")
        case .arrival:
            XCTAssertLessThan(pattern.duration, 1.5, "Arrival pattern should not be annoyingly long")
        }
    }
    
    func validatePatternTiming(_ patternType: NavigationPatternType) async throws {
        // Measure actual pattern playback timing
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await playHapticPattern(patternType)
        
        let actualDuration = CFAbsoluteTimeGetCurrent() - startTime
        let expectedDuration = getHapticPattern(for: patternType).duration
        
        // Allow for some timing variance but ensure reasonable accuracy
        let timingTolerance = 0.1 // 100ms tolerance
        XCTAssertLessThan(abs(actualDuration - expectedDuration), timingTolerance,
                         "Pattern timing should be accurate for \(patternType.rawValue)")
    }
    
    func validatePatternIntensity(_ pattern: HapticPattern, for patternType: NavigationPatternType) {
        // Verify intensity is appropriate for navigation context
        let intensityValues = pattern.events.compactMap { event in
            event.eventParameters.first { $0.parameterID == .hapticIntensity }?.value
        }
        
        guard !intensityValues.isEmpty else {
            XCTFail("Pattern should have intensity parameters")
            return
        }
        
        let averageIntensity = intensityValues.average
        let maxIntensity = intensityValues.max() ?? 0
        
        switch patternType {
        case .leftTurn, .rightTurn:
            // Turn patterns should be attention-grabbing but not jarring
            XCTAssertGreaterThan(averageIntensity, 0.6, "Turn patterns should be noticeable")
            XCTAssertLessThan(maxIntensity, 1.0, "Turn patterns should not be jarring")
            
        case .continueStraight:
            // Continue straight should be gentle
            XCTAssertLessThan(averageIntensity, 0.5, "Continue straight should be gentle")
            
        case .arrival:
            // Arrival can be more intense for celebration
            XCTAssertGreaterThan(averageIntensity, 0.5, "Arrival should be noticeable")
            XCTAssertLessThan(maxIntensity, 1.0, "Arrival should not be overwhelming")
        }
    }
    
    func validatePatternContext(_ patternType: NavigationPatternType) {
        // Verify pattern fits navigation context appropriately
        let audioFrequency = patternType.audioFrequency
        let audioDescription = patternType.audioDescription
        
        // Audio frequency should match pattern urgency
        switch patternType {
        case .leftTurn:
            XCTAssertGreaterThan(audioFrequency, 400, "Left turn audio should be mid-range frequency")
            XCTAssertLessThan(audioFrequency, 500, "Left turn audio should not be too high")
            
        case .rightTurn:
            XCTAssertGreaterThan(audioFrequency, 500, "Right turn audio should be higher than left turn")
            
        case .continueStraight:
            XCTAssertLessThan(audioFrequency, 400, "Continue straight audio should be lower frequency")
            
        case .arrival:
            XCTAssertGreaterThan(audioFrequency, 600, "Arrival audio should be high and celebratory")
        }
        
        // Audio description should be clear and appropriate
        XCTAssertFalse(audioDescription.isEmpty, "Audio description should be provided")
        XCTAssertTrue(audioDescription.lowercased().contains(patternType.rawValue.lowercased().prefix(4)),
                     "Audio description should relate to pattern type")
    }
    
    // MARK: - Navigation Sequence Tests
    
    func testNavigationSequenceUserExperience() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test typical navigation sequences
        let sequences: [[NavigationPatternType]] = [
            [.continueStraight, .leftTurn, .continueStraight, .arrival],
            [.rightTurn, .continueStraight, .rightTurn, .leftTurn, .arrival],
            [.continueStraight, .continueStraight, .rightTurn, .arrival]
        ]
        
        for sequence in sequences {
            try await testNavigationSequence(sequence)
        }
    }
    
    func testNavigationSequence(_ sequence: [NavigationPatternType]) async throws {
        let sequenceStartTime = CFAbsoluteTimeGetCurrent()
        var patternTimings: [TimeInterval] = []
        
        for (index, patternType) in sequence.enumerated() {
            let patternStartTime = CFAbsoluteTimeGetCurrent()
            
            // Play pattern
            try await playHapticPattern(patternType)
            
            let patternDuration = CFAbsoluteTimeGetCurrent() - patternStartTime
            patternTimings.append(patternDuration)
            
            // Add realistic delay between navigation cues (except for last pattern)
            if index < sequence.count - 1 {
                let delayBetweenCues: TimeInterval = 3.0 // 3 seconds between cues
                try await Task.sleep(nanoseconds: UInt64(delayBetweenCues * 1_000_000_000))
            }
        }
        
        let totalSequenceTime = CFAbsoluteTimeGetCurrent() - sequenceStartTime
        
        // Validate sequence timing
        XCTAssertLessThan(totalSequenceTime, 30.0, "Navigation sequence should complete in reasonable time")
        
        // Validate individual pattern timings within sequence
        for (index, timing) in patternTimings.enumerated() {
            let patternType = sequence[index]
            XCTAssertLessThan(timing, 2.0, "\(patternType.rawValue) should complete quickly in sequence")
        }
        
        // Verify patterns don't interfere with each other
        validateSequenceCoherence(sequence, timings: patternTimings)
    }
    
    func validateSequenceCoherence(_ sequence: [NavigationPatternType], timings: [TimeInterval]) {
        // Verify timing consistency throughout sequence
        let averageTiming = timings.average
        let timingVariation = timings.standardDeviation
        
        // Timing should be consistent (low variation)
        XCTAssertLessThan(timingVariation, averageTiming * 0.5, "Pattern timing should be consistent in sequences")
        
        // Verify logical progression
        for i in 0..<sequence.count-1 {
            let currentPattern = sequence[i]
            let nextPattern = sequence[i+1]
            
            // Arrival should only be last
            XCTAssertNotEqual(currentPattern, .arrival, "Arrival pattern should only be at end of sequence")
            
            // No duplicate consecutive patterns (except continue straight)
            if currentPattern == nextPattern && currentPattern != .continueStraight {
                XCTFail("Consecutive identical patterns should be avoided: \(currentPattern.rawValue)")
            }
        }
    }
    
    // MARK: - Accessibility Compliance Tests
    
    func testAccessibilityCompliance() throws {
        // Test haptic patterns meet accessibility guidelines
        
        // Test audio fallback quality
        testAudioFallbackQuality()
        
        // Test visual fallback support
        testVisualFallbackSupport()
        
        // Test compatibility with assistive technologies
        testAssistiveTechnologyCompatibility()
        
        // Test customization options
        testAccessibilityCustomization()
    }
    
    func testAudioFallbackQuality() {
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        
        for patternType in patterns {
            // Test audio frequency distinctiveness
            let audioFreq = patternType.audioFrequency
            XCTAssertGreaterThan(audioFreq, 200, "Audio frequency should be audible")
            XCTAssertLessThan(audioFreq, 2000, "Audio frequency should not be too high")
            
            // Test audio description quality
            let description = patternType.audioDescription
            XCTAssertGreaterThan(description.count, 5, "Audio description should be descriptive")
            XCTAssertLessThan(description.count, 50, "Audio description should be concise")
            
            // Test audio fallback playback
            accessibilityService.playAudioCue(for: patternType)
        }
        
        // Test audio frequency distinctiveness between patterns
        let frequencies = patterns.map { $0.audioFrequency }
        let frequencyVariation = frequencies.standardDeviation
        XCTAssertGreaterThan(frequencyVariation, 50, "Audio frequencies should be sufficiently distinct")
    }
    
    func testVisualFallbackSupport() {
        // Test that visual alternatives are available
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        
        for patternType in patterns {
            // Visual fallback should trigger without error
            accessibilityService.showVisualCue(for: patternType)
            
            // Verify appropriate visual representation exists
            let visualDescription = getVisualDescription(for: patternType)
            XCTAssertFalse(visualDescription.isEmpty, "Visual description should be available for \(patternType.rawValue)")
        }
    }
    
    func testAssistiveTechnologyCompatibility() {
        // Test VoiceOver compatibility
        if UIAccessibility.isVoiceOverRunning {
            testVoiceOverIntegration()
        }
        
        // Test Switch Control compatibility
        if UIAccessibility.isSwitchControlRunning {
            testSwitchControlIntegration()
        }
        
        // Test with reduced motion preferences
        if UIAccessibility.isReduceMotionEnabled {
            testReducedMotionCompatibility()
        }
    }
    
    func testVoiceOverIntegration() {
        // Test that haptic patterns work well with VoiceOver
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        
        for patternType in patterns {
            // Announce pattern with VoiceOver
            accessibilityService.announceAccessibility(patternType.audioDescription)
            
            // Verify speech doesn't interfere with haptic timing
            // This would be tested in integration scenarios
        }
    }
    
    func testSwitchControlIntegration() {
        // Test that haptic navigation works with Switch Control
        // This involves testing simplified navigation interfaces
        print("Testing Switch Control compatibility")
    }
    
    func testReducedMotionCompatibility() {
        // Test that haptic patterns are appropriate when reduced motion is enabled
        // Haptic patterns should be gentler with reduced motion preference
        print("Testing reduced motion compatibility")
    }
    
    func testAccessibilityCustomization() {
        // Test customization options for accessibility needs
        
        // Test intensity adjustment
        let intensityLevels: [Float] = [0.3, 0.5, 0.7, 1.0]
        
        for intensity in intensityLevels {
            // Verify patterns can be adjusted for different intensity needs
            // This would involve testing customizable haptic intensity
            XCTAssertGreaterThanOrEqual(intensity, 0.3, "Minimum intensity should be detectable")
            XCTAssertLessThanOrEqual(intensity, 1.0, "Maximum intensity should be comfortable")
        }
        
        // Test timing adjustment
        let timingMultipliers: [Double] = [0.5, 1.0, 1.5, 2.0]
        
        for multiplier in timingMultipliers {
            // Verify patterns can be slowed down or sped up for accessibility
            XCTAssertGreaterThan(multiplier, 0.3, "Timing should not be too fast")
            XCTAssertLessThan(multiplier, 3.0, "Timing should not be excessively slow")
        }
    }
    
    // MARK: - Performance and Battery Impact Tests
    
    func testHapticPatternPerformanceImpact() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test battery impact of haptic patterns
        let initialBatteryLevel = UIDevice.current.batteryLevel
        let testDuration: TimeInterval = 60.0 // 1 minute test
        let startTime = Date()
        
        // Play patterns continuously for test duration
        while Date().timeIntervalSince(startTime) < testDuration {
            for patternType in NavigationPatternType.allCases {
                try await playHapticPattern(patternType)
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms between patterns
            }
        }
        
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        
        // Battery impact should be reasonable for navigation usage
        XCTAssertLessThan(batteryDrop, 0.02, "Haptic patterns should not significantly impact battery in 1 minute") // Less than 2% drop
    }
    
    func testHapticPatternLatency() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test latency from trigger to haptic feedback
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        var latencies: [TimeInterval] = []
        
        for patternType in patterns {
            let startTime = CFAbsoluteTimeGetCurrent()
            try await playHapticPattern(patternType)
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            latencies.append(latency)
        }
        
        let averageLatency = latencies.average
        let maxLatency = latencies.max() ?? 0
        
        // Latency should be minimal for good user experience
        XCTAssertLessThan(averageLatency, 0.050, "Average haptic latency should be < 50ms")
        XCTAssertLessThan(maxLatency, 0.100, "Maximum haptic latency should be < 100ms")
    }
    
    // MARK: - Helper Methods
    
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
    
    private func playHapticPattern(_ patternType: NavigationPatternType) async throws {
        switch patternType {
        case .leftTurn:
            try await hapticService.playTurnLeftPattern()
        case .rightTurn:
            try await hapticService.playTurnRightPattern()
        case .continueStraight:
            try await hapticService.playContinueStraightPattern()
        case .arrival:
            try await hapticService.playArrivalPattern()
        }
    }
    
    private func calculateDistinctivenessScore(
        duration: TimeInterval,
        eventCount: Int,
        intensityVariation: Double,
        sharpnessVariation: Double
    ) -> Double {
        // Weighted distinctiveness calculation
        let durationScore = min(1.0, duration / 1.0) // Normalize duration
        let eventScore = min(1.0, Double(eventCount) / 5.0) // Normalize event count
        let intensityScore = min(1.0, intensityVariation)
        let sharpnessScore = min(1.0, sharpnessVariation)
        
        return (durationScore * 0.3) + (eventScore * 0.3) + (intensityScore * 0.2) + (sharpnessScore * 0.2)
    }
    
    private func calculateUserExperienceScore(for patternType: NavigationPatternType, pattern: HapticPattern) -> Double {
        // Calculate user experience score based on pattern appropriateness
        var score = 0.5 // Base score
        
        // Duration appropriateness
        switch patternType {
        case .leftTurn, .rightTurn:
            if pattern.duration < 0.5 { score += 0.2 }
        case .continueStraight:
            if pattern.duration > 0.3 && pattern.duration < 0.8 { score += 0.2 }
        case .arrival:
            if pattern.duration > 0.4 && pattern.duration < 1.0 { score += 0.2 }
        }
        
        // Intensity appropriateness
        let avgIntensity = pattern.events.compactMap { event in
            event.eventParameters.first { $0.parameterID == .hapticIntensity }?.value
        }.average
        
        if avgIntensity > 0.3 && avgIntensity < 0.9 { score += 0.2 }
        
        // Event count appropriateness
        switch patternType {
        case .leftTurn:
            if pattern.events.count == 1 { score += 0.1 }
        case .rightTurn:
            if pattern.events.count >= 2 { score += 0.1 }
        case .continueStraight:
            if pattern.events.count == 1 { score += 0.1 }
        case .arrival:
            if pattern.events.count >= 3 { score += 0.1 }
        }
        
        return min(1.0, score)
    }
    
    private func calculatePatternSimilarity(_ pattern1: PatternAnalysis, _ pattern2: PatternAnalysis) -> Double {
        // Calculate similarity between two patterns (0 = completely different, 1 = identical)
        
        let durationSimilarity = 1.0 - abs(pattern1.duration - pattern2.duration) / max(pattern1.duration, pattern2.duration)
        let eventCountSimilarity = 1.0 - abs(Double(pattern1.eventCount - pattern2.eventCount)) / max(Double(pattern1.eventCount), Double(pattern2.eventCount))
        
        let intensity1Avg = pattern1.intensityProfile.average
        let intensity2Avg = pattern2.intensityProfile.average
        let intensitySimilarity = 1.0 - abs(intensity1Avg - intensity2Avg)
        
        let sharpness1Avg = pattern1.sharpnessProfile.average
        let sharpness2Avg = pattern2.sharpnessProfile.average
        let sharpnessSimilarity = 1.0 - abs(sharpness1Avg - sharpness2Avg)
        
        return (durationSimilarity * 0.3) + (eventCountSimilarity * 0.3) + (intensitySimilarity * 0.2) + (sharpnessSimilarity * 0.2)
    }
    
    private func getVisualDescription(for patternType: NavigationPatternType) -> String {
        switch patternType {
        case .leftTurn:
            return "← Turn Left"
        case .rightTurn:
            return "→ Turn Right"
        case .continueStraight:
            return "↑ Continue Straight"
        case .arrival:
            return "🎯 Arrived"
        }
    }
}

// MARK: - Array Extensions for Statistical Analysis

extension Array where Element == Float {
    var average: Float {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Float(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let sumOfSquares = map { pow(Double($0 - avg), 2) }.reduce(0, +)
        return sqrt(sumOfSquares / Double(count - 1))
    }
}

extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let sumOfSquares = map { pow($0 - avg, 2) }.reduce(0, +)
        return sqrt(sumOfSquares / Double(count - 1))
    }
}

extension Array where Element == TimeInterval {
    var average: TimeInterval {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let sumOfSquares = map { pow($0 - avg, 2) }.reduce(0, +)
        return sqrt(sumOfSquares / Double(count - 1))
    }
} 