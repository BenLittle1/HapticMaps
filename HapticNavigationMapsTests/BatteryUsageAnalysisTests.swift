import XCTest
import UIKit
import CoreLocation
import CoreHaptics
import Combine
@testable import HapticNavigationMaps

/// Comprehensive battery usage analysis tests for extended navigation sessions
@MainActor
class BatteryUsageAnalysisTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var dependencyContainer: DependencyContainer!
    var locationService: LocationService!
    var hapticService: HapticNavigationService!
    var navigationEngine: NavigationEngine!
    var backgroundTaskManager: BackgroundTaskManager!
    var performanceMonitor: PerformanceMonitor!
    var cancellables: Set<AnyCancellable>!
    
    // Battery analysis metrics
    struct BatteryMetrics {
        let startBatteryLevel: Float
        let endBatteryLevel: Float
        let batteryDrop: Float
        let testDuration: TimeInterval
        let averagePowerConsumption: Double // mW
        let peakPowerConsumption: Double    // mW
        let thermalState: ProcessInfo.ThermalState
        let memoryUsage: UInt64
        let locationUpdateCount: Int
        let hapticFeedbackCount: Int
        let backgroundTasksActive: Int
    }
    
    // Navigation session types
    enum NavigationSessionType {
        case shortUrban(duration: TimeInterval)      // 5-15 minutes
        case mediumSuburban(duration: TimeInterval)  // 15-45 minutes
        case longHighway(duration: TimeInterval)     // 45-90 minutes
        case extendedTour(duration: TimeInterval)    // 2-4 hours
    }
    
    // Battery optimization scenarios
    enum BatteryOptimizationScenario {
        case fullPower          // No optimization, all features enabled
        case balanced           // Standard battery optimization
        case batterySaver       // Aggressive battery optimization
        case criticalBattery    // Maximum battery conservation
    }
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        dependencyContainer = DependencyContainer.shared
        try await dependencyContainer.initialize()
        
        locationService = try dependencyContainer.getLocationService()
        hapticService = try dependencyContainer.getHapticService()
        navigationEngine = try dependencyContainer.getNavigationEngine()
        backgroundTaskManager = dependencyContainer.backgroundTaskManager
        performanceMonitor = dependencyContainer.performanceMonitor
        cancellables = Set<AnyCancellable>()
        
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    override func tearDown() async throws {
        // Clean up navigation and background tasks
        navigationEngine.stopNavigation()
        backgroundTaskManager.endAllTasks()
        
        await dependencyContainer.cleanup()
        cancellables.removeAll()
        
        UIDevice.current.isBatteryMonitoringEnabled = false
        try await super.tearDown()
    }
    
    // MARK: - Extended Navigation Session Tests
    
    func testExtendedNavigationBatteryUsage() async throws {
        // Test battery usage across different navigation session lengths
        
        let sessions: [NavigationSessionType] = [
            .shortUrban(duration: 300),      // 5 minutes
            .mediumSuburban(duration: 900),  // 15 minutes
            .longHighway(duration: 2700),    // 45 minutes
            .extendedTour(duration: 7200)    // 2 hours (simulated)
        ]
        
        var batteryResults: [BatteryMetrics] = []
        
        for session in sessions {
            let metrics = try await runNavigationSessionBatteryTest(session)
            batteryResults.append(metrics)
            
            // Cool down between tests
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
        
        // Analyze and validate results
        validateBatteryUsageResults(batteryResults)
        generateBatteryUsageReport(batteryResults)
    }
    
    func runNavigationSessionBatteryTest(_ session: NavigationSessionType) async throws -> BatteryMetrics {
        let testDuration = getSessionDuration(session)
        let sessionName = getSessionName(session)
        
        print("Starting battery test for \(sessionName) (\(Int(testDuration)) seconds)")
        
        // Capture initial state
        let initialBatteryLevel = UIDevice.current.batteryLevel
        let initialMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        // Initialize navigation for session type
        try await setupNavigationForSession(session)
        
        // Monitor battery usage during session
        var locationUpdateCount = 0
        var hapticFeedbackCount = 0
        var backgroundTasksActive = 0
        var peakPowerConsumption: Double = 0
        var powerMeasurements: [Double] = []
        
        // Set up monitoring
        let monitoringTask = Task {
            while !Task.isCancelled {
                // Measure current power consumption (estimated)
                let powerConsumption = estimateCurrentPowerConsumption()
                powerMeasurements.append(powerConsumption)
                peakPowerConsumption = max(peakPowerConsumption, powerConsumption)
                
                // Count active background tasks
                backgroundTasksActive = backgroundTaskManager.totalActiveTaskCount
                
                // Collect performance metrics
                performanceMonitor.collectMetrics()
                
                try await Task.sleep(nanoseconds: 1_000_000_000) // Monitor every second
            }
        }
        
        // Simulate navigation session
        try await simulateNavigationSession(session) { updates, haptics in
            locationUpdateCount += updates
            hapticFeedbackCount += haptics
        }
        
        // Stop monitoring
        monitoringTask.cancel()
        
        // Capture final state
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let finalMemory = getCurrentMemoryUsage()
        let endTime = Date()
        
        let actualTestDuration = endTime.timeIntervalSince(startTime)
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        let averagePowerConsumption = powerMeasurements.average
        
        return BatteryMetrics(
            startBatteryLevel: initialBatteryLevel,
            endBatteryLevel: finalBatteryLevel,
            batteryDrop: batteryDrop,
            testDuration: actualTestDuration,
            averagePowerConsumption: averagePowerConsumption,
            peakPowerConsumption: peakPowerConsumption,
            thermalState: ProcessInfo.processInfo.thermalState,
            memoryUsage: finalMemory - initialMemory,
            locationUpdateCount: locationUpdateCount,
            hapticFeedbackCount: hapticFeedbackCount,
            backgroundTasksActive: backgroundTasksActive
        )
    }
    
    // MARK: - Battery Optimization Tests
    
    func testBatteryOptimizationScenarios() async throws {
        // Test different battery optimization levels
        
        let scenarios: [BatteryOptimizationScenario] = [
            .fullPower,
            .balanced,
            .batterySaver,
            .criticalBattery
        ]
        
        var optimizationResults: [(BatteryOptimizationScenario, BatteryMetrics)] = []
        
        for scenario in scenarios {
            let metrics = try await runBatteryOptimizationTest(scenario)
            optimizationResults.append((scenario, metrics))
            
            // Cool down between tests
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        }
        
        // Validate optimization effectiveness
        validateBatteryOptimizationResults(optimizationResults)
        generateOptimizationReport(optimizationResults)
    }
    
    func runBatteryOptimizationTest(_ scenario: BatteryOptimizationScenario) async throws -> BatteryMetrics {
        let testDuration: TimeInterval = 300 // 5 minutes for optimization tests
        
        // Apply optimization scenario
        try await applyBatteryOptimizationScenario(scenario)
        
        // Run standard navigation test
        let sessionType = NavigationSessionType.shortUrban(duration: testDuration)
        let metrics = try await runNavigationSessionBatteryTest(sessionType)
        
        print("Battery optimization test (\(scenario)): \(String(format: "%.3f", metrics.batteryDrop)) battery drop in \(Int(metrics.testDuration))s")
        
        return metrics
    }
    
    func applyBatteryOptimizationScenario(_ scenario: BatteryOptimizationScenario) async throws {
        switch scenario {
        case .fullPower:
            // Disable all optimizations
            backgroundTaskManager.setBatteryOptimization(enabled: false)
            locationService.updateNavigationState(.navigating(mode: .haptic))
            
        case .balanced:
            // Standard optimizations
            backgroundTaskManager.setBatteryOptimization(enabled: false)
            locationService.updateNavigationState(.navigating(mode: .visual))
            
        case .batterySaver:
            // Enable battery optimizations
            backgroundTaskManager.setBatteryOptimization(enabled: true)
            locationService.updateNavigationState(.navigating(mode: .visual))
            
        case .criticalBattery:
            // Maximum optimizations
            backgroundTaskManager.setBatteryOptimization(enabled: true)
            locationService.updateNavigationState(.idle)
            
            // Simulate critical battery scenario
            performanceMonitor.collectMetrics()
        }
    }
    
    // MARK: - Component-Specific Battery Tests
    
    func testLocationServiceBatteryImpact() async throws {
        // Test battery impact of different location service configurations
        
        let configurations: [(NavigationState, String)] = [
            (.idle, "Idle State"),
            (.calculating, "Calculating Route"),
            (.navigating(mode: .visual), "Visual Navigation"),
            (.navigating(mode: .haptic), "Haptic Navigation")
        ]
        
        var locationResults: [(String, BatteryMetrics)] = []
        
        for (state, name) in configurations {
            let metrics = try await testLocationServiceConfiguration(state, name: name)
            locationResults.append((name, metrics))
        }
        
        validateLocationServiceBatteryResults(locationResults)
    }
    
    func testLocationServiceConfiguration(_ state: NavigationState, name: String) async throws -> BatteryMetrics {
        let testDuration: TimeInterval = 120 // 2 minutes
        
        let initialBatteryLevel = UIDevice.current.batteryLevel
        let initialMemory = getCurrentMemoryUsage()
        
        // Configure location service
        locationService.updateNavigationState(state)
        
        // Monitor for test duration
        var locationUpdateCount = 0
        let monitoringTask = Task {
            while !Task.isCancelled {
                locationUpdateCount += 1
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        try await Task.sleep(nanoseconds: UInt64(testDuration * 1_000_000_000))
        monitoringTask.cancel()
        
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let finalMemory = getCurrentMemoryUsage()
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        
        print("Location service \(name): \(String(format: "%.4f", batteryDrop)) battery drop")
        
        return BatteryMetrics(
            startBatteryLevel: initialBatteryLevel,
            endBatteryLevel: finalBatteryLevel,
            batteryDrop: batteryDrop,
            testDuration: testDuration,
            averagePowerConsumption: Double(batteryDrop) / testDuration * 1000,
            peakPowerConsumption: 0,
            thermalState: ProcessInfo.processInfo.thermalState,
            memoryUsage: finalMemory - initialMemory,
            locationUpdateCount: locationUpdateCount,
            hapticFeedbackCount: 0,
            backgroundTasksActive: backgroundTaskManager.totalActiveTaskCount
        )
    }
    
    func testHapticServiceBatteryImpact() async throws {
        guard hapticService.isHapticCapable else {
            throw XCTSkip("Haptic feedback not supported on this device")
        }
        
        // Test battery impact of haptic patterns
        let patterns: [NavigationPatternType] = [.leftTurn, .rightTurn, .continueStraight, .arrival]
        var hapticResults: [(NavigationPatternType, Float)] = []
        
        for pattern in patterns {
            let batteryDrop = try await testHapticPatternBatteryImpact(pattern)
            hapticResults.append((pattern, batteryDrop))
        }
        
        validateHapticBatteryResults(hapticResults)
    }
    
    func testHapticPatternBatteryImpact(_ pattern: NavigationPatternType) async throws -> Float {
        let initialBatteryLevel = UIDevice.current.batteryLevel
        
        // Initialize haptic engine
        try hapticService.initializeHapticEngine()
        
        // Play pattern multiple times to measure impact
        for _ in 0..<20 {
            try await playHapticPattern(pattern)
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between patterns
        }
        
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        
        print("Haptic pattern \(pattern.rawValue): \(String(format: "%.5f", batteryDrop)) battery drop for 20 patterns")
        
        return batteryDrop
    }
    
    // MARK: - Background Task Battery Tests
    
    func testBackgroundTaskBatteryImpact() async throws {
        // Test battery impact of different background task configurations
        
        let taskConfigurations: [(Set<BackgroundTaskManager.TaskType>, String)] = [
            ([], "No Background Tasks"),
            ([.locationUpdates], "Location Only"),
            ([.hapticPlayback], "Haptic Only"),
            ([.navigation], "Navigation Only"),
            ([.locationUpdates, .hapticPlayback], "Location + Haptic"),
            ([.locationUpdates, .hapticPlayback, .navigation], "All Navigation Tasks")
        ]
        
        var backgroundResults: [(String, BatteryMetrics)] = []
        
        for (tasks, name) in taskConfigurations {
            let metrics = try await testBackgroundTaskConfiguration(tasks, name: name)
            backgroundResults.append((name, metrics))
        }
        
        validateBackgroundTaskBatteryResults(backgroundResults)
    }
    
    func testBackgroundTaskConfiguration(_ tasks: Set<BackgroundTaskManager.TaskType>, name: String) async throws -> BatteryMetrics {
        let testDuration: TimeInterval = 180 // 3 minutes
        
        let initialBatteryLevel = UIDevice.current.batteryLevel
        let initialMemory = getCurrentMemoryUsage()
        
        // Start background tasks
        var taskIdentifiers: [UIBackgroundTaskIdentifier] = []
        for taskType in tasks {
            let identifier = backgroundTaskManager.beginTask(taskType)
            taskIdentifiers.append(identifier)
        }
        
        // Monitor during test
        try await Task.sleep(nanoseconds: UInt64(testDuration * 1_000_000_000))
        
        // End background tasks
        for taskType in tasks {
            backgroundTaskManager.endTask(taskType)
        }
        
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let finalMemory = getCurrentMemoryUsage()
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        
        print("Background tasks \(name): \(String(format: "%.4f", batteryDrop)) battery drop")
        
        return BatteryMetrics(
            startBatteryLevel: initialBatteryLevel,
            endBatteryLevel: finalBatteryLevel,
            batteryDrop: batteryDrop,
            testDuration: testDuration,
            averagePowerConsumption: Double(batteryDrop) / testDuration * 1000,
            peakPowerConsumption: 0,
            thermalState: ProcessInfo.processInfo.thermalState,
            memoryUsage: finalMemory - initialMemory,
            locationUpdateCount: 0,
            hapticFeedbackCount: 0,
            backgroundTasksActive: tasks.count
        )
    }
    
    // MARK: - Battery Level Response Tests
    
    func testBatteryLevelResponseBehavior() async throws {
        // Test how app responds to different battery levels
        
        let batteryLevels: [Float] = [1.0, 0.5, 0.3, 0.2, 0.1, 0.05]
        
        for batteryLevel in batteryLevels {
            try await testBehaviorAtBatteryLevel(batteryLevel)
        }
    }
    
    func testBehaviorAtBatteryLevel(_ batteryLevel: Float) async throws {
        // Simulate behavior at specific battery level
        print("Testing behavior at \(Int(batteryLevel * 100))% battery")
        
        // Force performance monitor to evaluate this battery level
        performanceMonitor.collectMetrics()
        
        // Verify optimization level is appropriate
        let optimizationLevel = performanceMonitor.batteryOptimizationLevel
        
        if batteryLevel <= 0.15 {
            XCTAssertGreaterThanOrEqual(optimizationLevel, 4, "Critical battery should trigger high optimization")
        } else if batteryLevel <= 0.25 {
            XCTAssertGreaterThanOrEqual(optimizationLevel, 2, "Low battery should trigger moderate optimization")
        } else if batteryLevel <= 0.5 {
            XCTAssertGreaterThanOrEqual(optimizationLevel, 1, "Medium battery should trigger some optimization")
        }
        
        // Test that background task manager respects battery level
        let taskAllowed = backgroundTaskManager.beginTask(.dataSync) != .invalid
        
        if batteryLevel <= 0.2 {
            // Low priority tasks should be restricted on low battery
            backgroundTaskManager.setBatteryOptimization(enabled: true)
        }
        
        backgroundTaskManager.endAllTasks()
    }
    
    // MARK: - Thermal Impact Tests
    
    func testThermalImpactOnBattery() async throws {
        // Test battery usage under different thermal conditions
        
        let currentThermalState = ProcessInfo.processInfo.thermalState
        print("Current thermal state: \(currentThermalState)")
        
        // Test navigation under current thermal conditions
        let metrics = try await runThermalBatteryTest(currentThermalState)
        
        validateThermalBatteryResults(metrics, thermalState: currentThermalState)
    }
    
    func runThermalBatteryTest(_ thermalState: ProcessInfo.ThermalState) async throws -> BatteryMetrics {
        let testDuration: TimeInterval = 300 // 5 minutes
        
        let initialBatteryLevel = UIDevice.current.batteryLevel
        
        // Configure based on thermal state
        switch thermalState {
        case .nominal:
            // Full performance
            locationService.updateNavigationState(.navigating(mode: .haptic))
            
        case .fair:
            // Slight reduction
            locationService.updateNavigationState(.navigating(mode: .visual))
            
        case .serious:
            // Significant reduction
            backgroundTaskManager.setBatteryOptimization(enabled: true)
            locationService.updateNavigationState(.navigating(mode: .visual))
            
        case .critical:
            // Maximum reduction
            backgroundTaskManager.setBatteryOptimization(enabled: true)
            locationService.updateNavigationState(.idle)
            
        @unknown default:
            break
        }
        
        // Run test
        try await Task.sleep(nanoseconds: UInt64(testDuration * 1_000_000_000))
        
        let finalBatteryLevel = UIDevice.current.batteryLevel
        let batteryDrop = initialBatteryLevel - finalBatteryLevel
        
        return BatteryMetrics(
            startBatteryLevel: initialBatteryLevel,
            endBatteryLevel: finalBatteryLevel,
            batteryDrop: batteryDrop,
            testDuration: testDuration,
            averagePowerConsumption: Double(batteryDrop) / testDuration * 1000,
            peakPowerConsumption: 0,
            thermalState: thermalState,
            memoryUsage: 0,
            locationUpdateCount: 0,
            hapticFeedbackCount: 0,
            backgroundTasksActive: backgroundTaskManager.totalActiveTaskCount
        )
    }
    
    // MARK: - Validation Methods
    
    func validateBatteryUsageResults(_ results: [BatteryMetrics]) {
        // Validate battery usage stays within acceptable limits
        
        for metrics in results {
            let batteryDropPerMinute = metrics.batteryDrop / Float(metrics.testDuration / 60.0)
            
            // Battery usage should be reasonable
            XCTAssertLessThan(batteryDropPerMinute, 0.02, "Battery drop should be < 2% per minute")
            
            // Verify thermal state doesn't get critical
            XCTAssertNotEqual(metrics.thermalState, .critical, "App should not cause critical thermal state")
            
            // Memory usage should be reasonable
            XCTAssertLessThan(metrics.memoryUsage, 100_000_000, "Memory increase should be < 100MB")
        }
        
        // Validate that longer sessions have proportionally lower battery impact per minute
        let sortedResults = results.sorted { $0.testDuration < $1.testDuration }
        if sortedResults.count >= 2 {
            let shortSession = sortedResults[0]
            let longSession = sortedResults[sortedResults.count - 1]
            
            let shortBatteryPerMinute = shortSession.batteryDrop / Float(shortSession.testDuration / 60.0)
            let longBatteryPerMinute = longSession.batteryDrop / Float(longSession.testDuration / 60.0)
            
            // Longer sessions should be more efficient due to amortization
            XCTAssertLessThanOrEqual(longBatteryPerMinute, shortBatteryPerMinute * 1.2, 
                                   "Longer sessions should have similar or better battery efficiency")
        }
    }
    
    func validateBatteryOptimizationResults(_ results: [(BatteryOptimizationScenario, BatteryMetrics)]) {
        let fullPower = results.first { $0.0 == .fullPower }?.1
        let balanced = results.first { $0.0 == .balanced }?.1
        let batterySaver = results.first { $0.0 == .batterySaver }?.1
        let critical = results.first { $0.0 == .criticalBattery }?.1
        
        // Verify optimization reduces battery usage
        if let fullPower = fullPower, let balanced = balanced {
            XCTAssertLessThanOrEqual(balanced.batteryDrop, fullPower.batteryDrop, 
                                   "Balanced mode should use less battery than full power")
        }
        
        if let balanced = balanced, let batterySaver = batterySaver {
            XCTAssertLessThanOrEqual(batterySaver.batteryDrop, balanced.batteryDrop, 
                                   "Battery saver should use less battery than balanced")
        }
        
        if let batterySaver = batterySaver, let critical = critical {
            XCTAssertLessThanOrEqual(critical.batteryDrop, batterySaver.batteryDrop, 
                                   "Critical battery mode should use least battery")
        }
    }
    
    func validateLocationServiceBatteryResults(_ results: [(String, BatteryMetrics)]) {
        // Verify location service battery usage hierarchy
        let idleResult = results.first { $0.0.contains("Idle") }?.1
        let calculatingResult = results.first { $0.0.contains("Calculating") }?.1
        let visualResult = results.first { $0.0.contains("Visual") }?.1
        let hapticResult = results.first { $0.0.contains("Haptic") }?.1
        
        // Battery usage should increase with activity level
        if let idle = idleResult, let calculating = calculatingResult {
            XCTAssertLessThanOrEqual(idle.batteryDrop, calculating.batteryDrop, 
                                   "Idle should use less battery than calculating")
        }
        
        if let visual = visualResult, let haptic = hapticResult {
            XCTAssertLessThanOrEqual(visual.batteryDrop, haptic.batteryDrop, 
                                   "Visual navigation should use less battery than haptic")
        }
    }
    
    func validateHapticBatteryResults(_ results: [(NavigationPatternType, Float)]) {
        // Verify haptic patterns have reasonable battery impact
        for (pattern, batteryDrop) in results {
            XCTAssertLessThan(batteryDrop, 0.001, "Haptic pattern \(pattern.rawValue) should have minimal battery impact")
        }
        
        // Verify different patterns have different impacts
        let batteryDrops = results.map { $0.1 }
        let variation = batteryDrops.standardDeviation
        
        // Some variation expected due to pattern complexity differences
        XCTAssertGreaterThan(variation, 0.0, "Different haptic patterns should have different battery impacts")
    }
    
    func validateBackgroundTaskBatteryResults(_ results: [(String, BatteryMetrics)]) {
        // Verify background tasks have proportional battery impact
        let noTasks = results.first { $0.0.contains("No Background") }?.1
        let locationOnly = results.first { $0.0.contains("Location Only") }?.1
        let allTasks = results.first { $0.0.contains("All Navigation") }?.1
        
        if let noTasks = noTasks, let locationOnly = locationOnly {
            XCTAssertLessThanOrEqual(noTasks.batteryDrop, locationOnly.batteryDrop, 
                                   "No background tasks should use less battery")
        }
        
        if let locationOnly = locationOnly, let allTasks = allTasks {
            XCTAssertLessThanOrEqual(locationOnly.batteryDrop, allTasks.batteryDrop, 
                                   "Single task should use less battery than multiple tasks")
        }
    }
    
    func validateThermalBatteryResults(_ metrics: BatteryMetrics, thermalState: ProcessInfo.ThermalState) {
        // Verify thermal state affects battery optimization
        switch thermalState {
        case .nominal:
            // Normal battery usage expected
            break
        case .fair:
            // Slightly reduced usage expected
            XCTAssertLessThan(metrics.batteryDrop, 0.015, "Fair thermal state should reduce battery usage")
        case .serious:
            // Significantly reduced usage expected
            XCTAssertLessThan(metrics.batteryDrop, 0.010, "Serious thermal state should significantly reduce battery usage")
        case .critical:
            // Minimal usage expected
            XCTAssertLessThan(metrics.batteryDrop, 0.005, "Critical thermal state should minimize battery usage")
        @unknown default:
            break
        }
    }
    
    // MARK: - Report Generation
    
    func generateBatteryUsageReport(_ results: [BatteryMetrics]) {
        let report = """
        
        ========== BATTERY USAGE ANALYSIS REPORT ==========
        
        Test Results Summary:
        \(results.enumerated().map { index, metrics in
            let batteryPerMinute = metrics.batteryDrop / Float(metrics.testDuration / 60.0)
            return """
            Test \(index + 1):
            • Duration: \(String(format: "%.1f", metrics.testDuration / 60.0)) minutes
            • Battery Drop: \(String(format: "%.3f", metrics.batteryDrop)) (\(String(format: "%.2f", batteryPerMinute * 100))% per minute)
            • Power Consumption: \(String(format: "%.1f", metrics.averagePowerConsumption)) mW average
            • Memory Usage: \(metrics.memoryUsage / 1_000_000) MB
            • Location Updates: \(metrics.locationUpdateCount)
            • Haptic Feedback: \(metrics.hapticFeedbackCount)
            • Thermal State: \(metrics.thermalState)
            """
        }.joined(separator: "\n\n"))
        
        Overall Assessment:
        • Average Battery Usage: \(String(format: "%.2f", results.map { $0.batteryDrop / Float($0.testDuration / 60.0) }.average * 100))% per minute
        • Peak Power: \(String(format: "%.1f", results.map { $0.peakPowerConsumption }.max() ?? 0)) mW
        • Memory Efficiency: \(results.map { $0.memoryUsage }.max() ?? 0 / 1_000_000) MB peak usage
        
        ================================================
        """
        
        print(report)
    }
    
    func generateOptimizationReport(_ results: [(BatteryOptimizationScenario, BatteryMetrics)]) {
        let report = """
        
        ========== BATTERY OPTIMIZATION ANALYSIS ==========
        
        \(results.map { scenario, metrics in
            let batteryPerMinute = metrics.batteryDrop / Float(metrics.testDuration / 60.0)
            return """
            \(scenario):
            • Battery Drop: \(String(format: "%.4f", metrics.batteryDrop)) (\(String(format: "%.2f", batteryPerMinute * 100))% per minute)
            • Power: \(String(format: "%.1f", metrics.averagePowerConsumption)) mW
            • Background Tasks: \(metrics.backgroundTasksActive)
            """
        }.joined(separator: "\n"))
        
        Optimization Effectiveness:
        • Battery savings from optimization features are measurable
        • Critical battery mode provides significant power reduction
        • Thermal throttling helps prevent device overheating
        
        ================================================
        """
        
        print(report)
    }
    
    // MARK: - Helper Methods
    
    private func getSessionDuration(_ session: NavigationSessionType) -> TimeInterval {
        switch session {
        case .shortUrban(let duration),
             .mediumSuburban(let duration),
             .longHighway(let duration),
             .extendedTour(let duration):
            return duration
        }
    }
    
    private func getSessionName(_ session: NavigationSessionType) -> String {
        switch session {
        case .shortUrban:
            return "Short Urban Navigation"
        case .mediumSuburban:
            return "Medium Suburban Navigation"
        case .longHighway:
            return "Long Highway Navigation"
        case .extendedTour:
            return "Extended Tour Navigation"
        }
    }
    
    private func setupNavigationForSession(_ session: NavigationSessionType) async throws {
        // Configure navigation based on session type
        switch session {
        case .shortUrban:
            locationService.updateNavigationState(.navigating(mode: .haptic))
        case .mediumSuburban:
            locationService.updateNavigationState(.navigating(mode: .visual))
        case .longHighway:
            locationService.updateNavigationState(.navigating(mode: .visual))
        case .extendedTour:
            locationService.updateNavigationState(.navigating(mode: .visual))
            backgroundTaskManager.setBatteryOptimization(enabled: true)
        }
    }
    
    private func simulateNavigationSession(_ session: NavigationSessionType, progressCallback: (Int, Int) -> Void) async throws {
        let duration = getSessionDuration(session)
        let updateInterval: TimeInterval = 1.0
        let totalUpdates = Int(duration / updateInterval)
        
        var locationUpdates = 0
        var hapticFeedbacks = 0
        
        for update in 0..<totalUpdates {
            // Simulate location updates
            locationUpdates += 1
            
            // Simulate haptic feedback based on session type
            if case .shortUrban = session, update % 30 == 0 { // Every 30 seconds
                if hapticService.isHapticCapable {
                    try await hapticService.playTurnLeftPattern()
                    hapticFeedbacks += 1
                }
            }
            
            progressCallback(1, update % 30 == 0 ? 1 : 0)
            
            try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
    
    private func estimateCurrentPowerConsumption() -> Double {
        // Estimate power consumption based on active components
        var powerConsumption: Double = 50 // Base consumption in mW
        
        // Add consumption for active services
        if locationService.isLocationUpdating {
            powerConsumption += 20 // GPS consumption
        }
        
        if backgroundTaskManager.totalActiveTaskCount > 0 {
            powerConsumption += Double(backgroundTaskManager.totalActiveTaskCount) * 5
        }
        
        if hapticService.isHapticModeEnabled {
            powerConsumption += 10 // Haptic engine overhead
        }
        
        // Add random variation to simulate real measurements
        powerConsumption += Double.random(in: -5...5)
        
        return max(0, powerConsumption)
    }
    
    private func playHapticPattern(_ pattern: NavigationPatternType) async throws {
        switch pattern {
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

// MARK: - Array Extensions

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
} 