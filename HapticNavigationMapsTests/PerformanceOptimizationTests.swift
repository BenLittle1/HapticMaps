import XCTest
import CoreLocation
import CoreHaptics
import Combine
@testable import HapticNavigationMaps

/// Performance tests for location updates, haptic feedback, and battery management optimizations
@MainActor
class PerformanceOptimizationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var locationService: LocationService!
    var hapticService: HapticNavigationService!
    var backgroundTaskManager: BackgroundTaskManager!
    var performanceMonitor: PerformanceMonitor!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize services
        locationService = LocationService()
        hapticService = HapticNavigationService()
        backgroundTaskManager = BackgroundTaskManager.shared
        performanceMonitor = PerformanceMonitor.shared
        cancellables = Set<AnyCancellable>()
        
        // Start performance monitoring for tests
        performanceMonitor.startMonitoring(
            locationService: locationService,
            hapticService: hapticService,
            backgroundTaskManager: backgroundTaskManager
        )
    }
    
    override func tearDown() async throws {
        // Clean up
        performanceMonitor.stopMonitoring()
        cancellables.removeAll()
        
        try await super.tearDown()
    }
    
    // MARK: - Location Update Performance Tests
    
    func testAdaptiveLocationUpdateFrequency() throws {
        // Test that location update frequency adapts based on navigation state
        
        // Measure baseline configuration
        let idleConfig = LocationUpdateConfiguration.idle
        XCTAssertGreaterThan(idleConfig.distanceFilter, 20.0, "Idle mode should use larger distance filter for battery savings")
        XCTAssertEqual(idleConfig.accuracy, kCLLocationAccuracyHundredMeters, "Idle mode should use lower accuracy")
        
        // Test calculating configuration
        let calculatingConfig = LocationUpdateConfiguration.calculating
        XCTAssertLessThan(calculatingConfig.distanceFilter, idleConfig.distanceFilter, "Calculating mode should have higher precision")
        XCTAssertEqual(calculatingConfig.accuracy, kCLLocationAccuracyBest, "Calculating mode should use best accuracy")
        
        // Test navigation configurations
        let visualNavConfig = LocationUpdateConfiguration.navigatingVisual
        let hapticNavConfig = LocationUpdateConfiguration.navigatingHaptic
        
        XCTAssertLessThan(hapticNavConfig.distanceFilter, visualNavConfig.distanceFilter, "Haptic navigation should have highest precision")
        XCTAssertEqual(hapticNavConfig.accuracy, kCLLocationAccuracyBestForNavigation, "Haptic navigation should use best navigation accuracy")
        
        // Test background configurations
        let backgroundIdleConfig = LocationUpdateConfiguration.backgroundIdle
        let backgroundNavConfig = LocationUpdateConfiguration.backgroundNavigating
        
        XCTAssertGreaterThan(backgroundIdleConfig.distanceFilter, backgroundNavConfig.distanceFilter, "Background idle should be more conservative")
        XCTAssertLessThan(backgroundNavConfig.accuracy, backgroundIdleConfig.accuracy, "Background navigation should balance accuracy and battery")
    }
    
    func testLocationUpdateOptimizationPerformance() async throws {
        // Performance test for location update state transitions
        
        let expectation = expectation(description: "Location configuration changes")
        expectation.expectedFulfillmentCount = 4
        
        var configurationChanges: [NavigationState] = []
        
        // Monitor navigation state changes
        locationService.$currentNavigationState
            .sink { state in
                configurationChanges.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Measure time for state transitions
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test state transitions
        locationService.updateNavigationState(.calculating)
        locationService.updateNavigationState(.navigating(mode: .visual))
        locationService.updateNavigationState(.navigating(mode: .haptic))
        locationService.updateNavigationState(.idle)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        let transitionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Verify performance
        XCTAssertLessThan(transitionTime, 0.1, "Location configuration transitions should be fast (< 100ms)")
        XCTAssertEqual(configurationChanges.count, 4, "Should have recorded all state changes")
        
        // Verify final state
        XCTAssertEqual(locationService.currentNavigationState, .idle, "Should end in idle state")
    }
    
    func testLocationUpdateFrequencyMeasurement() async throws {
        // Test location update frequency measurement accuracy
        
        let expectation = expectation(description: "Location updates measured")
        expectation.expectedFulfillmentCount = 1
        
        // Start location updates in high-frequency mode
        locationService.updateNavigationState(.navigating(mode: .haptic))
        
        // Wait for frequency measurements
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 3.0)
        
        // Verify frequency measurement exists
        let frequency = locationService.currentUpdateFrequency
        XCTAssertGreaterThanOrEqual(frequency, 0.0, "Update frequency should be non-negative")
        
        // Note: Actual frequency depends on location updates being received
        // In a real device test, this would verify actual GPS update rates
    }
    
    // MARK: - Haptic Pattern Caching Tests
    
    func testHapticPatternCacheInitialization() throws {
        // Skip test if haptics not supported
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test haptic engine initialization with pattern preloading
        let initializationExpectation = expectation(description: "Haptic engine initialized")
        
        Task {
            do {
                try hapticService.initializeHapticEngine()
                initializationExpectation.fulfill()
            } catch {
                XCTFail("Failed to initialize haptic engine: \(error)")
            }
        }
        
        wait(for: [initializationExpectation], timeout: 5.0)
        
        // Verify engine state
        XCTAssertEqual(hapticService.engineState, .running, "Haptic engine should be running after initialization")
    }
    
    func testHapticPatternCachePerformance() async throws {
        // Skip test if haptics not supported
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Initialize haptic engine
        try hapticService.initializeHapticEngine()
        
        // Measure pattern playback performance
        let patternPlayCount = 10
        var playbackTimes: [TimeInterval] = []
        
        for _ in 0..<patternPlayCount {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try await hapticService.playTurnLeftPattern()
                let playbackTime = CFAbsoluteTimeGetCurrent() - startTime
                playbackTimes.append(playbackTime)
                
                // Wait between patterns to avoid overlap
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                XCTFail("Failed to play haptic pattern: \(error)")
            }
        }
        
        // Analyze performance
        let averagePlaybackTime = playbackTimes.reduce(0, +) / Double(playbackTimes.count)
        let maxPlaybackTime = playbackTimes.max() ?? 0
        
        // Performance assertions
        XCTAssertLessThan(averagePlaybackTime, 0.050, "Average haptic pattern playback should be < 50ms")
        XCTAssertLessThan(maxPlaybackTime, 0.100, "Maximum haptic pattern playback should be < 100ms")
        
        // Verify cache hit rate (after initial patterns are cached)
        let cacheHitRate = hapticService.patternCacheHitRate
        XCTAssertGreaterThan(cacheHitRate, 0.7, "Cache hit rate should improve with repeated pattern usage")
    }
    
    func testHapticPatternCacheMemoryUsage() throws {
        // Skip test if haptics not supported
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Measure memory before haptic initialization
        let memoryBefore = getCurrentMemoryUsage()
        
        // Initialize haptic engine with pattern caching
        try hapticService.initializeHapticEngine()
        
        // Measure memory after initialization
        let memoryAfter = getCurrentMemoryUsage()
        
        // Calculate memory increase
        let memoryIncrease = memoryAfter - memoryBefore
        
        // Verify reasonable memory usage (should be < 10MB for pattern cache)
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024, "Haptic pattern cache should use < 10MB memory")
        
        // Test cache cleanup
        hapticService.resetEngine()
        
        let memoryAfterCleanup = getCurrentMemoryUsage()
        let memoryDifference = memoryAfterCleanup - memoryBefore
        
        // Memory should be cleaned up (allow some variance for test overhead)
        XCTAssertLessThan(memoryDifference, 5 * 1024 * 1024, "Memory should be cleaned up after haptic engine reset")
    }
    
    // MARK: - Background Task Optimization Tests
    
    func testBackgroundTaskConsolidation() async throws {
        // Test that background task manager consolidates similar tasks
        
        let initialTaskCount = backgroundTaskManager.totalActiveTaskCount
        
        // Start multiple tasks of same type
        let task1 = backgroundTaskManager.beginTask(.locationUpdates)
        let task2 = backgroundTaskManager.beginTask(.locationUpdates) // Should replace task1
        
        // Verify only one task of each type exists
        XCTAssertEqual(backgroundTaskManager.totalActiveTaskCount, initialTaskCount + 1, "Should only have one location task")
        XCTAssertNotEqual(task1, .invalid, "First task should be valid")
        XCTAssertNotEqual(task2, .invalid, "Second task should be valid")
        
        // Start different task types
        let hapticTask = backgroundTaskManager.beginTask(.hapticPlayback)
        let navTask = backgroundTaskManager.beginTask(.navigation)
        
        XCTAssertEqual(backgroundTaskManager.totalActiveTaskCount, initialTaskCount + 3, "Should have three different task types")
        
        // Cleanup
        backgroundTaskManager.endTask(.locationUpdates)
        backgroundTaskManager.endTask(.hapticPlayback)
        backgroundTaskManager.endTask(.navigation)
        
        XCTAssertEqual(backgroundTaskManager.totalActiveTaskCount, initialTaskCount, "Should return to initial task count")
    }
    
    func testBatteryOptimizationBehavior() throws {
        // Test battery-based task optimization
        
        // Test normal battery behavior
        backgroundTaskManager.setBatteryOptimization(enabled: false)
        
        let lowPriorityTask = backgroundTaskManager.beginTask(.dataSync)
        XCTAssertNotEqual(lowPriorityTask, .invalid, "Low priority task should be allowed with good battery")
        
        // Test low battery behavior
        backgroundTaskManager.setBatteryOptimization(enabled: true)
        
        let anotherLowPriorityTask = backgroundTaskManager.beginTask(.dataSync)
        // This might be denied depending on current task load
        
        // High priority tasks should always be allowed
        let highPriorityTask = backgroundTaskManager.beginTask(.navigation)
        XCTAssertNotEqual(highPriorityTask, .invalid, "High priority task should always be allowed")
        
        // Cleanup
        backgroundTaskManager.endAllTasks()
    }
    
    func testBackgroundTaskPerformanceMetrics() async throws {
        // Test background task performance tracking
        
        let expectation = expectation(description: "Task metrics updated")
        
        // Monitor task metrics
        backgroundTaskManager.$taskSuccessRate
            .dropFirst() // Skip initial value
            .sink { successRate in
                XCTAssertGreaterThanOrEqual(successRate, 0.0, "Success rate should be non-negative")
                XCTAssertLessThanOrEqual(successRate, 1.0, "Success rate should not exceed 100%")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Create and complete some tasks
        let task1 = backgroundTaskManager.beginTask(.hapticPlayback)
        backgroundTaskManager.endTask(.hapticPlayback)
        
        let task2 = backgroundTaskManager.beginTask(.locationUpdates)
        backgroundTaskManager.endTask(.locationUpdates)
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMetricsCollection() async throws {
        // Test comprehensive performance metrics collection
        
        let expectation = expectation(description: "Performance metrics collected")
        
        // Monitor performance metrics updates
        performanceMonitor.$currentMetrics
            .compactMap { $0 }
            .first()
            .sink { metrics in
                // Verify all metric components exist
                XCTAssertGreaterThan(metrics.memoryUsage.totalMemory, 0, "Memory usage should be positive")
                XCTAssertGreaterThanOrEqual(metrics.locationMetrics.updateFrequency, 0, "Update frequency should be non-negative")
                XCTAssertGreaterThanOrEqual(metrics.hapticMetrics.patternCacheHitRate, 0, "Cache hit rate should be non-negative")
                XCTAssertGreaterThanOrEqual(metrics.backgroundTaskMetrics.activeTaskCount, 0, "Task count should be non-negative")
                XCTAssertGreaterThanOrEqual(metrics.batteryLevel, 0, "Battery level should be non-negative")
                
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Force metrics collection
        performanceMonitor.collectMetrics()
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testPerformanceScoreCalculation() throws {
        // Test performance score calculation accuracy
        
        // Force metrics collection
        performanceMonitor.collectMetrics()
        
        let performanceScore = performanceMonitor.performanceScore
        
        // Verify score is in valid range
        XCTAssertGreaterThanOrEqual(performanceScore, 0.0, "Performance score should be >= 0")
        XCTAssertLessThanOrEqual(performanceScore, 1.0, "Performance score should be <= 1")
        
        // Test performance recommendations
        let recommendations = performanceMonitor.getPerformanceRecommendations()
        XCTAssertFalse(recommendations.isEmpty, "Should provide performance recommendations")
    }
    
    func testPerformanceOptimizationLevels() async throws {
        // Test that performance optimization levels adjust based on conditions
        
        let expectation = expectation(description: "Optimization level updated")
        
        // Monitor optimization level changes
        performanceMonitor.$batteryOptimizationLevel
            .dropFirst() // Skip initial value
            .sink { level in
                XCTAssertGreaterThanOrEqual(level, 0, "Optimization level should be >= 0")
                XCTAssertLessThanOrEqual(level, 5, "Optimization level should be <= 5")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger optimization by collecting metrics
        performanceMonitor.collectMetrics()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Integration Performance Tests
    
    func testOverallSystemPerformance() async throws {
        // Integration test for overall system performance
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate navigation workflow
        locationService.updateNavigationState(.calculating)
        
        if hapticService.isHapticCapable {
            try hapticService.initializeHapticEngine()
        }
        
        locationService.updateNavigationState(.navigating(mode: .haptic))
        
        // Start background tasks
        let navTask = backgroundTaskManager.beginTask(.navigation)
        let locationTask = backgroundTaskManager.beginTask(.locationUpdates)
        
        // Collect performance metrics
        performanceMonitor.collectMetrics()
        
        // Simulate some navigation activity
        if hapticService.isHapticCapable {
            try await hapticService.playTurnLeftPattern()
            try await hapticService.playTurnRightPattern()
        }
        
        // End navigation
        locationService.updateNavigationState(.arrived)
        backgroundTaskManager.endAllTasks()
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance assertions
        XCTAssertLessThan(totalTime, 2.0, "Complete navigation workflow should be fast (< 2 seconds)")
        
        // Verify system is in good state
        let finalMetrics = performanceMonitor.currentMetrics
        XCTAssertNotNil(finalMetrics, "Performance metrics should be available")
        
        if let metrics = finalMetrics {
            XCTAssertGreaterThan(performanceMonitor.performanceScore, 0.5, "Performance score should be reasonable after workflow")
        }
    }
    
    func testMemoryUsageUnderLoad() async throws {
        // Test memory usage under sustained load
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Simulate sustained navigation activity
        for iteration in 0..<100 {
            // Update navigation state
            let mode: NavigationMode = iteration % 2 == 0 ? .visual : .haptic
            locationService.updateNavigationState(.navigating(mode: mode))
            
            // Play haptic patterns (if supported)
            if hapticService.isHapticCapable && iteration % 10 == 0 {
                do {
                    try hapticService.initializeHapticEngine()
                    try await hapticService.playTurnLeftPattern()
                } catch {
                    // Ignore haptic errors in performance test
                }
            }
            
            // Collect metrics periodically
            if iteration % 20 == 0 {
                performanceMonitor.collectMetrics()
            }
            
            // Small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Verify memory usage doesn't grow excessively
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory usage should not increase by more than 50MB under load")
        
        // Clean up
        locationService.updateNavigationState(.idle)
        backgroundTaskManager.endAllTasks()
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
} 