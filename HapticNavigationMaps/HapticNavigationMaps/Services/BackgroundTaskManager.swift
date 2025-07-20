import UIKit
import Foundation
import Combine

/// Centralized background task manager for optimizing battery usage
@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    // MARK: - Background Task Types
    
    enum TaskType: String, CaseIterable {
        case navigation = "Navigation"
        case hapticPlayback = "HapticPlayback"
        case locationUpdates = "LocationUpdates"
        case dataSync = "DataSync"
        
        var priority: Int {
            switch self {
            case .navigation:
                return 3 // Highest priority
            case .hapticPlayback:
                return 2
            case .locationUpdates:
                return 1
            case .dataSync:
                return 0 // Lowest priority
            }
        }
        
        var maxDuration: TimeInterval {
            switch self {
            case .navigation:
                return 180.0 // 3 minutes
            case .hapticPlayback:
                return 30.0  // 30 seconds
            case .locationUpdates:
                return 600.0 // 10 minutes
            case .dataSync:
                return 30.0  // 30 seconds
            }
        }
    }
    
    // MARK: - Background Task State
    
    private struct BackgroundTask {
        let identifier: UIBackgroundTaskIdentifier
        let taskType: TaskType
        let startTime: Date
        let expirationHandler: (() -> Void)?
        
        var isExpired: Bool {
            Date().timeIntervalSince(startTime) >= taskType.maxDuration
        }
        
        var remainingTime: TimeInterval {
            max(0, taskType.maxDuration - Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Properties
    
    @Published private(set) var activeTasks: [TaskType: String] = [:]
    @Published private(set) var totalActiveTaskCount: Int = 0
    @Published private(set) var isBackgroundExecutionAvailable: Bool = true
    
    // Internal storage with full task info
    private var internalActiveTasks: [TaskType: BackgroundTask] = [:]
    
    private var taskCleanupTimer: Timer?
    private var batteryOptimizationEnabled: Bool = true
    private let maxConcurrentTasks: Int = 3
    
    // Performance monitoring
    private var taskStartCount: Int = 0
    private var taskCompletionCount: Int = 0
    private var taskExpirationCount: Int = 0
    private var lastMetricsReset: Date = Date()
    @Published private(set) var taskSuccessRate: Double = 1.0
    
    // MARK: - Initialization
    
    private init() {
        setupBackgroundMonitoring()
        startTaskCleanup()
    }
    
    deinit {
        taskCleanupTimer?.invalidate()
        // End all tasks during cleanup
        Task { 
            await MainActor.run {
                endAllTasks()
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Begin a background task of specified type
    func beginTask(
        _ taskType: TaskType,
        expirationHandler: (() -> Void)? = nil
    ) -> UIBackgroundTaskIdentifier {
        
        // Check if we should allow this task based on battery optimization
        guard shouldAllowTask(taskType) else {
            print("Background task \(taskType.rawValue) denied due to battery optimization")
            return .invalid
        }
        
        // End any existing task of the same type
        endTask(taskType)
        
        // Create new background task
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskType.rawValue) { [weak self] in
            Task { @MainActor in
                self?.handleTaskExpiration(taskType)
                expirationHandler?()
            }
        }
        
        guard taskIdentifier != .invalid else {
            print("Failed to create background task for \(taskType.rawValue)")
            return .invalid
        }
        
        // Store task info
        let backgroundTask = BackgroundTask(
            identifier: taskIdentifier,
            taskType: taskType,
            startTime: Date(),
            expirationHandler: expirationHandler
        )
        
        internalActiveTasks[taskType] = backgroundTask
        activeTasks[taskType] = taskType.rawValue
        updateTaskCount()
        taskStartCount += 1
        
        print("Started background task: \(taskType.rawValue) (ID: \(taskIdentifier))")
        return taskIdentifier
    }
    
    /// End a background task of specified type
    func endTask(_ taskType: TaskType) {
        guard let task = internalActiveTasks[taskType] else { return }
        
        UIApplication.shared.endBackgroundTask(task.identifier)
        internalActiveTasks.removeValue(forKey: taskType)
        activeTasks.removeValue(forKey: taskType)
        updateTaskCount()
        taskCompletionCount += 1
        
        print("Ended background task: \(taskType.rawValue) (ID: \(task.identifier))")
    }
    
    /// End all active background tasks
    func endAllTasks() {
        for (taskType, task) in internalActiveTasks {
            UIApplication.shared.endBackgroundTask(task.identifier)
            print("Ended background task: \(taskType.rawValue) (ID: \(task.identifier))")
        }
        internalActiveTasks.removeAll()
        activeTasks.removeAll()
        updateTaskCount()
    }
    
    /// Check if a task type is currently active
    func isTaskActive(_ taskType: TaskType) -> Bool {
        return activeTasks[taskType] != nil
    }
    
    /// Get remaining time for a task type
    func getRemainingTime(for taskType: TaskType) -> TimeInterval {
        return internalActiveTasks[taskType]?.remainingTime ?? 0
    }
    
    /// Enable or disable battery optimization
    func setBatteryOptimization(enabled: Bool) {
        batteryOptimizationEnabled = enabled
        
        if enabled {
            // End low-priority tasks to save battery
            endLowPriorityTasks()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillEnterForeground()
            }
        }
        
        // Monitor battery level changes
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBatteryLevelChanged()
            }
        }
    }
    
    private func shouldAllowTask(_ taskType: TaskType) -> Bool {
        // Always allow high-priority tasks
        if taskType.priority >= 2 {
            return true
        }
        
        // Check if we're at the concurrent task limit
        if totalActiveTaskCount >= maxConcurrentTasks {
            return false
        }
        
        // Battery optimization checks
        if batteryOptimizationEnabled {
            let batteryLevel = UIDevice.current.batteryLevel
            
            // More restrictive on low battery
            if batteryLevel < 0.2 && taskType.priority < 2 {
                return false
            }
            
            // Don't allow low-priority tasks if other tasks are running
            if taskType.priority == 0 && totalActiveTaskCount > 0 {
                return false
            }
        }
        
        return true
    }
    
    private func updateTaskCount() {
        totalActiveTaskCount = internalActiveTasks.count
    }
    
    private func startTaskCleanup() {
        taskCleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredTasks()
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func cleanupExpiredTasks() {
        let expiredTasks = internalActiveTasks.filter { $0.value.isExpired }
        
        for (taskType, _) in expiredTasks {
            print("Cleaning up expired task: \(taskType.rawValue)")
            endTask(taskType)
            taskExpirationCount += 1
        }
    }
    
    private func handleTaskExpiration(_ taskType: TaskType) {
        print("Background task expired: \(taskType.rawValue)")
        endTask(taskType)
        taskExpirationCount += 1
    }
    
    private func endLowPriorityTasks() {
        let lowPriorityTasks = internalActiveTasks.filter { $0.value.taskType.priority < 2 }
        
        for (taskType, _) in lowPriorityTasks {
            print("Ending low-priority task for battery optimization: \(taskType.rawValue)")
            endTask(taskType)
        }
    }
    
    private func updatePerformanceMetrics() {
        let totalTasks = taskStartCount + taskCompletionCount + taskExpirationCount
        if totalTasks > 0 {
            taskSuccessRate = Double(taskCompletionCount) / Double(totalTasks)
        }
        
        // Reset metrics periodically
        if Date().timeIntervalSince(lastMetricsReset) > 300.0 { // 5 minutes
            taskStartCount = 0
            taskCompletionCount = 0
            taskExpirationCount = 0
            lastMetricsReset = Date()
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppDidEnterBackground() {
        print("App entered background - managing \(totalActiveTaskCount) active tasks")
        
        // Enable battery optimization if device is on low battery
        if UIDevice.current.batteryLevel < 0.3 {
            setBatteryOptimization(enabled: true)
        }
    }
    
    private func handleAppWillEnterForeground() {
        print("App entering foreground - cleaning up background tasks")
        
        // Clean up any expired tasks
        cleanupExpiredTasks()
        
        // Less restrictive battery optimization in foreground
        if UIDevice.current.batteryLevel > 0.2 {
            setBatteryOptimization(enabled: false)
        }
    }
    
    private func handleBatteryLevelChanged() {
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel < 0.15 {
            // Very low battery - end all non-critical tasks
            print("Very low battery detected - ending non-critical background tasks")
            let criticalTasks = internalActiveTasks.filter { $0.value.taskType.priority >= 3 }
            endAllTasks()
            
            // Restart only critical tasks
            for (taskType, _) in criticalTasks {
                _ = beginTask(taskType)
            }
            
            setBatteryOptimization(enabled: true)
        } else if batteryLevel < 0.25 {
            // Low battery - enable battery optimization
            setBatteryOptimization(enabled: true)
        } else if batteryLevel > 0.5 {
            // Good battery level - allow more tasks
            setBatteryOptimization(enabled: false)
        }
    }
}

// MARK: - Debug Information

extension BackgroundTaskManager {
    /// Get debug information about active tasks
    func getDebugInfo() -> [String: Any] {
        var tasksInfo: [[String: Any]] = []
        for (taskType, task) in internalActiveTasks {
            let taskInfo = [
                "taskType": task.taskType.rawValue,
                "startTime": task.startTime,
                "remainingTime": task.remainingTime,
                "isExpired": task.isExpired
            ] as [String: Any]
            tasksInfo.append(taskInfo)
        }
        return [
            "activeTasks": tasksInfo,
            "totalActiveTaskCount": totalActiveTaskCount,
            "taskSuccessRate": taskSuccessRate,
            "batteryOptimizationEnabled": batteryOptimizationEnabled,
            "batteryLevel": UIDevice.current.batteryLevel
        ]
    }
} 