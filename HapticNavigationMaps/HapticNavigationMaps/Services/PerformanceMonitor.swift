import Foundation
import UIKit
import Combine
import CoreLocation
import os.log

/// Comprehensive performance monitoring service for tracking app performance and battery usage
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Performance Metrics
    
    struct PerformanceMetrics {
        let timestamp: Date
        let memoryUsage: MemoryUsage
        let locationMetrics: LocationMetrics
        let hapticMetrics: HapticMetrics
        let backgroundTaskMetrics: BackgroundTaskMetrics
        let batteryLevel: Float
        let thermalState: ProcessInfo.ThermalState
    }
    
    struct MemoryUsage {
        let totalMemory: UInt64      // Total app memory usage in bytes
        let peakMemory: UInt64       // Peak memory usage since app start
        let memoryPressure: MemoryPressureLevel
        let swapUsage: UInt64        // Swap usage in bytes
    }
    
    enum MemoryPressureLevel: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate" 
        case high = "High"
        case critical = "Critical"
    }
    
    struct LocationMetrics {
        let updateFrequency: Double        // Updates per second
        let averageAccuracy: Double        // Average accuracy in meters
        let gpsSignalStrength: Double      // Signal strength percentage
        let powerConsumption: PowerLevel   // Estimated power consumption
    }
    
    struct HapticMetrics {
        let patternCacheHitRate: Double    // Cache hit percentage
        let averagePatternLatency: Double  // Average time to play pattern (ms)
        let totalPatternPlays: Int         // Total patterns played
        let failureRate: Double            // Pattern failure percentage
    }
    
    struct BackgroundTaskMetrics {
        let activeTaskCount: Int           // Number of active background tasks
        let taskSuccessRate: Double        // Task completion success rate
        let averageTaskDuration: Double    // Average task duration in seconds
        let batteryImpact: PowerLevel      // Estimated battery impact
    }
    
    enum PowerLevel: String, CaseIterable {
        case veryLow = "Very Low"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var currentMetrics: PerformanceMetrics?
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var performanceScore: Double = 1.0 // 0.0-1.0 (1.0 = excellent)
    @Published private(set) var batteryOptimizationLevel: Int = 0 // 0-5 (5 = maximum optimization)
    
    // Historical data
    @Published private(set) var metricsHistory: [PerformanceMetrics] = []
    private let maxHistorySize: Int = 100
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 30.0 // 30 seconds
    private var cancellables = Set<AnyCancellable>()
    
    // Service references
    private weak var locationService: LocationService?
    private weak var hapticService: HapticNavigationService?
    private weak var backgroundTaskManager: BackgroundTaskManager?
    
    // Performance thresholds
    private let memoryWarningThreshold: UInt64 = 150 * 1024 * 1024 // 150MB
    private let locationUpdateRateThreshold: Double = 2.0 // Updates per second
    private let batteryOptimizationThreshold: Float = 0.3 // 30% battery
    
    // Logging
    private let performanceLogger = Logger(subsystem: "HapticNavigationMaps", category: "Performance")
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
        setupThermalStateObserver()
        setupBatteryStateObserver()
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Start performance monitoring
    func startMonitoring(
        locationService: LocationService,
        hapticService: HapticNavigationService,
        backgroundTaskManager: BackgroundTaskManager
    ) {
        guard !isMonitoring else { return }
        
        self.locationService = locationService
        self.hapticService = hapticService
        self.backgroundTaskManager = backgroundTaskManager
        
        isMonitoring = true
        startPeriodicMonitoring()
        
        performanceLogger.info("Performance monitoring started")
    }
    
    /// Stop performance monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        performanceLogger.info("Performance monitoring stopped")
    }
    
    /// Force a performance metrics collection
    func collectMetrics() {
        guard isMonitoring else { return }
        
        let metrics = gatherCurrentMetrics()
        updateMetrics(metrics)
        optimizePerformanceIfNeeded(metrics)
    }
    
    /// Get performance recommendations
    func getPerformanceRecommendations() -> [String] {
        guard let metrics = currentMetrics else {
            return ["Enable performance monitoring to get recommendations"]
        }
        
        var recommendations: [String] = []
        
        // Memory recommendations
        if metrics.memoryUsage.totalMemory > memoryWarningThreshold {
            recommendations.append("High memory usage detected. Consider reducing location update frequency.")
        }
        
        // Location recommendations
        if metrics.locationMetrics.updateFrequency > locationUpdateRateThreshold {
            recommendations.append("Location updates are very frequent. Consider using adaptive location configuration.")
        }
        
        // Battery recommendations
        if metrics.batteryLevel < batteryOptimizationThreshold {
            recommendations.append("Low battery detected. Enable battery optimization mode.")
        }
        
        // Haptic recommendations
        if metrics.hapticMetrics.patternCacheHitRate < 0.8 {
            recommendations.append("Low haptic pattern cache hit rate. Preload commonly used patterns.")
        }
        
        // Background task recommendations
        if metrics.backgroundTaskMetrics.activeTaskCount > 3 {
            recommendations.append("Many background tasks active. Consider consolidating or prioritizing tasks.")
        }
        
        return recommendations.isEmpty ? ["Performance is optimal"] : recommendations
    }
    
    /// Export performance data for analysis
    func exportPerformanceData() -> Data? {
        let exportData = [
            "exportDate": Date(),
            "currentMetrics": currentMetrics as Any,
            "metricsHistory": metricsHistory,
            "performanceScore": performanceScore,
            "batteryOptimizationLevel": batteryOptimizationLevel
        ] as [String: Any]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - Private Methods
    
    private func startPeriodicMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectMetrics()
            }
        }
        
        // Collect initial metrics
        collectMetrics()
    }
    
    private func gatherCurrentMetrics() -> PerformanceMetrics {
        let memoryUsage = getCurrentMemoryUsage()
        let locationMetrics = getLocationMetrics()
        let hapticMetrics = getHapticMetrics()
        let backgroundTaskMetrics = getBackgroundTaskMetrics()
        
        return PerformanceMetrics(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            locationMetrics: locationMetrics,
            hapticMetrics: hapticMetrics,
            backgroundTaskMetrics: backgroundTaskMetrics,
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let totalMemory = kerr == KERN_SUCCESS ? info.resident_size : 0
        
        // Monitor memory pressure
        let currentPressure = ProcessInfo.processInfo.thermalState
        
        // Update thermal state instead of memory pressure for now
        Task { @MainActor in
            switch currentPressure {
            case .nominal:
                // System is running normally
                break
            case .fair:
                // System is under light thermal pressure
                break
            case .serious:
                // System is under moderate thermal pressure  
                break
            case .critical:
                // System is under heavy thermal pressure
                break
            @unknown default:
                // Handle future cases
                break
            }
        }
        
        return MemoryUsage(
            totalMemory: totalMemory,
            peakMemory: totalMemory, // Simplified - could track actual peak
            memoryPressure: .low, // Placeholder, will be updated by thermal state
            swapUsage: 0 // iOS doesn't expose swap usage directly
        )
    }
    
    private func getLocationMetrics() -> LocationMetrics {
        guard let locationService = locationService else {
            return LocationMetrics(
                updateFrequency: 0,
                averageAccuracy: 0,
                gpsSignalStrength: 0,
                powerConsumption: .low
            )
        }
        
        let powerLevel: PowerLevel
        switch locationService.currentNavigationState {
        case .idle:
            powerLevel = .veryLow
        case .calculating:
            powerLevel = .moderate
        case .navigating(let mode):
            powerLevel = mode == .haptic ? .high : .moderate
        case .arrived:
            powerLevel = .low
        }
        
        return LocationMetrics(
            updateFrequency: locationService.currentUpdateFrequency,
            averageAccuracy: locationService.locationAccuracy,
            gpsSignalStrength: locationService.isGPSSignalStrong ? 1.0 : 0.5,
            powerConsumption: powerLevel
        )
    }
    
    private func getHapticMetrics() -> HapticMetrics {
        guard let hapticService = hapticService else {
            return HapticMetrics(
                patternCacheHitRate: 0,
                averagePatternLatency: 0,
                totalPatternPlays: 0,
                failureRate: 0
            )
        }
        
        return HapticMetrics(
            patternCacheHitRate: hapticService.patternCacheHitRate,
            averagePatternLatency: 10.0, // Simplified - could measure actual latency
            totalPatternPlays: 0, // Could track this
            failureRate: 0.0 // Could track failures
        )
    }
    
    private func getBackgroundTaskMetrics() -> BackgroundTaskMetrics {
        guard let backgroundTaskManager = backgroundTaskManager else {
            return BackgroundTaskMetrics(
                activeTaskCount: 0,
                taskSuccessRate: 1.0,
                averageTaskDuration: 0,
                batteryImpact: .low
            )
        }
        
        let batteryImpact: PowerLevel
        switch backgroundTaskManager.totalActiveTaskCount {
        case 0:
            batteryImpact = .veryLow
        case 1:
            batteryImpact = .low
        case 2:
            batteryImpact = .moderate
        case 3:
            batteryImpact = .high
        default:
            batteryImpact = .veryHigh
        }
        
        return BackgroundTaskMetrics(
            activeTaskCount: backgroundTaskManager.totalActiveTaskCount,
            taskSuccessRate: backgroundTaskManager.taskSuccessRate,
            averageTaskDuration: 60.0, // Could track actual durations
            batteryImpact: batteryImpact
        )
    }
    
    private func updateMetrics(_ metrics: PerformanceMetrics) {
        currentMetrics = metrics
        
        // Add to history
        metricsHistory.append(metrics)
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
        
        // Update performance score
        calculatePerformanceScore(metrics)
        
        // Log metrics
        performanceLogger.info("Performance metrics updated - Score: \(self.performanceScore), Battery: \(metrics.batteryLevel)")
    }
    
    private func calculatePerformanceScore(_ metrics: PerformanceMetrics) {
        var score: Double = 1.0
        
        // Memory score (0.3 weight)
        let memoryScore = max(0, 1.0 - Double(metrics.memoryUsage.totalMemory) / Double(memoryWarningThreshold))
        score *= 0.7 + (memoryScore * 0.3)
        
        // Location efficiency score (0.2 weight)
        let locationScore = min(1.0, 1.0 / max(1.0, metrics.locationMetrics.updateFrequency))
        score *= 0.8 + (locationScore * 0.2)
        
        // Haptic efficiency score (0.2 weight)
        let hapticScore = metrics.hapticMetrics.patternCacheHitRate
        score *= 0.8 + (hapticScore * 0.2)
        
        // Background task efficiency score (0.2 weight)
        let backgroundScore = max(0, 1.0 - Double(metrics.backgroundTaskMetrics.activeTaskCount) / 5.0)
        score *= 0.8 + (backgroundScore * 0.2)
        
        // Battery level impact (0.1 weight)
        let batteryScore = Double(metrics.batteryLevel)
        score *= 0.9 + (batteryScore * 0.1)
        
        performanceScore = max(0, min(1.0, score))
    }
    
    private func optimizePerformanceIfNeeded(_ metrics: PerformanceMetrics) {
        let previousOptimizationLevel = batteryOptimizationLevel
        
        // Determine optimization level based on metrics
        if metrics.batteryLevel < 0.15 || metrics.memoryUsage.memoryPressure == .critical {
            batteryOptimizationLevel = 5 // Maximum optimization
        } else if metrics.batteryLevel < 0.25 || metrics.memoryUsage.memoryPressure == .high {
            batteryOptimizationLevel = 4
        } else if metrics.batteryLevel < 0.35 || metrics.backgroundTaskMetrics.activeTaskCount > 3 {
            batteryOptimizationLevel = 3
        } else if metrics.locationMetrics.updateFrequency > 2.0 {
            batteryOptimizationLevel = 2
        } else if performanceScore < 0.8 {
            batteryOptimizationLevel = 1
        } else {
            batteryOptimizationLevel = 0
        }
        
        // Apply optimizations if level changed
        if batteryOptimizationLevel != previousOptimizationLevel {
            applyPerformanceOptimizations()
            performanceLogger.info("Performance optimization level changed to \(self.batteryOptimizationLevel)")
        }
    }
    
    private func applyPerformanceOptimizations() {
        // Notify services about optimization level changes
        NotificationCenter.default.post(
            name: NSNotification.Name("PerformanceOptimizationChanged"),
            object: nil,
            userInfo: [
                "optimizationLevel": batteryOptimizationLevel,
                "performanceScore": performanceScore
            ]
        )
        
        // Enable background task optimization for high optimization levels
        if batteryOptimizationLevel >= 3 {
            backgroundTaskManager?.setBatteryOptimization(enabled: true)
        } else {
            backgroundTaskManager?.setBatteryOptimization(enabled: false)
        }
    }
    
    // MARK: - System Observers
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func setupThermalStateObserver() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
    }
    
    private func setupBatteryStateObserver() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBatteryLevelChange()
            }
        }
    }
    
    private func handleMemoryWarning() {
        performanceLogger.warning("Memory warning received")
        batteryOptimizationLevel = min(5, batteryOptimizationLevel + 2)
        applyPerformanceOptimizations()
        collectMetrics()
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        performanceLogger.info("Thermal state changed to \(thermalState.rawValue)")
        
        switch thermalState {
        case .nominal:
            batteryOptimizationLevel = max(0, batteryOptimizationLevel - 1)
        case .fair:
            batteryOptimizationLevel = max(1, batteryOptimizationLevel)
        case .serious:
            batteryOptimizationLevel = max(3, batteryOptimizationLevel)
        case .critical:
            batteryOptimizationLevel = 5
        @unknown default:
            break
        }
        
        applyPerformanceOptimizations()
    }
    
    private func handleBatteryLevelChange() {
        collectMetrics()
    }
} 