import Foundation
import Combine
import MapKit

/// Service for managing user preferences and navigation state persistence
@MainActor
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    // MARK: - Published Properties
    
    @Published var preferredNavigationMode: NavigationMode {
        didSet {
            savePreferredNavigationMode(preferredNavigationMode)
        }
    }
    
    @Published var isHapticFeedbackEnabled: Bool {
        didSet {
            saveHapticFeedbackPreference(isHapticFeedbackEnabled)
        }
    }
    
    @Published var autoLockScreenInHapticMode: Bool {
        didSet {
            saveAutoLockPreference(autoLockScreenInHapticMode)
        }
    }
    
    @Published var screenLockTimeout: TimeInterval {
        didSet {
            saveScreenLockTimeout(screenLockTimeout)
        }
    }
    
    @Published var keepScreenAwakeInHapticMode: Bool {
        didSet {
            saveKeepScreenAwakePreference(keepScreenAwakeInHapticMode)
        }
    }
    
    // MARK: - Navigation State Persistence
    
    @Published private(set) var lastNavigationRoute: NavigationRouteState?
    @Published private(set) var lastNavigationMode: NavigationMode?
    @Published private(set) var lastNavigationProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults Keys
    private enum Keys {
        static let preferredNavigationMode = "preferredNavigationMode"
        static let isHapticFeedbackEnabled = "isHapticFeedbackEnabled"
        static let autoLockScreenInHapticMode = "autoLockScreenInHapticMode"
        static let screenLockTimeout = "screenLockTimeout"
        static let keepScreenAwakeInHapticMode = "keepScreenAwakeInHapticMode"
        static let lastNavigationRoute = "lastNavigationRoute"
        static let lastNavigationMode = "lastNavigationMode"
        static let lastNavigationProgress = "lastNavigationProgress"
        static let lastNavigationTimestamp = "lastNavigationTimestamp"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with default values first
        self.preferredNavigationMode = .visual
        self.isHapticFeedbackEnabled = true
        self.autoLockScreenInHapticMode = true
        self.screenLockTimeout = 30.0
        self.keepScreenAwakeInHapticMode = true
        
        // Then load saved preferences
        self.preferredNavigationMode = loadPreferredNavigationMode()
        self.isHapticFeedbackEnabled = loadHapticFeedbackPreference()
        self.autoLockScreenInHapticMode = loadAutoLockPreference()
        self.screenLockTimeout = loadScreenLockTimeout()
        self.keepScreenAwakeInHapticMode = loadKeepScreenAwakePreference()
        
        // Load last navigation state
        loadLastNavigationState()
    }
    
    // MARK: - Navigation Mode Preferences
    
    private func loadPreferredNavigationMode() -> NavigationMode {
        let rawValue = userDefaults.string(forKey: Keys.preferredNavigationMode) ?? "visual"
        return NavigationMode(rawValue: rawValue) ?? .visual
    }
    
    private func savePreferredNavigationMode(_ mode: NavigationMode) {
        userDefaults.set(mode.rawValue, forKey: Keys.preferredNavigationMode)
    }
    
    // MARK: - Haptic Feedback Preferences
    
    private func loadHapticFeedbackPreference() -> Bool {
        if userDefaults.object(forKey: Keys.isHapticFeedbackEnabled) == nil {
            // Default to true if never set
            return true
        }
        return userDefaults.bool(forKey: Keys.isHapticFeedbackEnabled)
    }
    
    private func saveHapticFeedbackPreference(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.isHapticFeedbackEnabled)
    }
    
    // MARK: - Screen Lock Preferences
    
    private func loadAutoLockPreference() -> Bool {
        if userDefaults.object(forKey: Keys.autoLockScreenInHapticMode) == nil {
            // Default to true if never set
            return true
        }
        return userDefaults.bool(forKey: Keys.autoLockScreenInHapticMode)
    }
    
    private func saveAutoLockPreference(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.autoLockScreenInHapticMode)
    }
    
    private func loadScreenLockTimeout() -> TimeInterval {
        let timeout = userDefaults.double(forKey: Keys.screenLockTimeout)
        return timeout > 0 ? timeout : 30.0 // Default 30 seconds
    }
    
    private func saveScreenLockTimeout(_ timeout: TimeInterval) {
        userDefaults.set(timeout, forKey: Keys.screenLockTimeout)
    }
    
    private func loadKeepScreenAwakePreference() -> Bool {
        if userDefaults.object(forKey: Keys.keepScreenAwakeInHapticMode) == nil {
            // Default to true if never set
            return true
        }
        return userDefaults.bool(forKey: Keys.keepScreenAwakeInHapticMode)
    }
    
    private func saveKeepScreenAwakePreference(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.keepScreenAwakeInHapticMode)
    }
    
    // MARK: - Navigation State Persistence
    
    /// Save navigation state based on NavigationState enum
    func saveNavigationState(_ state: NavigationState) {
        switch state {
        case .navigating(let mode):
            // Only save if actively navigating
            if let route = lastNavigationRoute {
                saveNavigationState(route: route, mode: mode, progress: lastNavigationProgress)
            }
        case .idle, .calculating, .arrived:
            // Clear navigation state for non-navigating states
            clearNavigationState()
        }
    }
    
    /// Save current navigation state for restoration
    func saveNavigationState(
        route: NavigationRouteState,
        mode: NavigationMode,
        progress: Double
    ) {
        do {
            let routeData = try JSONEncoder().encode(route)
            userDefaults.set(routeData, forKey: Keys.lastNavigationRoute)
            userDefaults.set(mode.rawValue, forKey: Keys.lastNavigationMode)
            userDefaults.set(progress, forKey: Keys.lastNavigationProgress)
            userDefaults.set(Date().timeIntervalSince1970, forKey: Keys.lastNavigationTimestamp)
            
            // Update published properties
            lastNavigationRoute = route
            lastNavigationMode = mode
            lastNavigationProgress = progress
        } catch {
            print("Failed to save navigation state: \(error)")
        }
    }
    
    /// Load last navigation state if it's recent (within 1 hour)
    private func loadLastNavigationState() {
        let timestamp = userDefaults.double(forKey: Keys.lastNavigationTimestamp)
        let lastNavTime = Date(timeIntervalSince1970: timestamp)
        
        // Only restore if within the last hour
        guard Date().timeIntervalSince(lastNavTime) < 3600 else {
            clearNavigationState()
            return
        }
        
        // Load route state
        if let routeData = userDefaults.data(forKey: Keys.lastNavigationRoute) {
            do {
                lastNavigationRoute = try JSONDecoder().decode(NavigationRouteState.self, from: routeData)
            } catch {
                print("Failed to decode navigation route: \(error)")
            }
        }
        
        // Load mode and progress
        if let modeString = userDefaults.string(forKey: Keys.lastNavigationMode) {
            lastNavigationMode = NavigationMode(rawValue: modeString)
        }
        
        lastNavigationProgress = userDefaults.double(forKey: Keys.lastNavigationProgress)
    }
    
    /// Clear saved navigation state
    func clearNavigationState() {
        userDefaults.removeObject(forKey: Keys.lastNavigationRoute)
        userDefaults.removeObject(forKey: Keys.lastNavigationMode)
        userDefaults.removeObject(forKey: Keys.lastNavigationProgress)
        userDefaults.removeObject(forKey: Keys.lastNavigationTimestamp)
        
        lastNavigationRoute = nil
        lastNavigationMode = nil
        lastNavigationProgress = 0.0
    }
    
    /// Check if there's a restorable navigation state
    var hasRestorableNavigationState: Bool {
        return lastNavigationRoute != nil && lastNavigationMode != nil
    }
    
    // MARK: - Reset Methods
    
    /// Reset all preferences to defaults
    func resetToDefaults() {
        preferredNavigationMode = .visual
        isHapticFeedbackEnabled = true
        autoLockScreenInHapticMode = true
        screenLockTimeout = 30.0
        keepScreenAwakeInHapticMode = true
        clearNavigationState()
    }
    
    /// Export preferences as dictionary
    func exportPreferences() -> [String: Any] {
        return [
            "preferredNavigationMode": preferredNavigationMode.rawValue,
            "isHapticFeedbackEnabled": isHapticFeedbackEnabled,
            "autoLockScreenInHapticMode": autoLockScreenInHapticMode,
            "screenLockTimeout": screenLockTimeout,
            "keepScreenAwakeInHapticMode": keepScreenAwakeInHapticMode
        ]
    }
    
    /// Import preferences from dictionary
    func importPreferences(from dict: [String: Any]) {
        if let modeString = dict["preferredNavigationMode"] as? String,
           let mode = NavigationMode(rawValue: modeString) {
            preferredNavigationMode = mode
        }
        
        if let hapticEnabled = dict["isHapticFeedbackEnabled"] as? Bool {
            isHapticFeedbackEnabled = hapticEnabled
        }
        
        if let autoLock = dict["autoLockScreenInHapticMode"] as? Bool {
            autoLockScreenInHapticMode = autoLock
        }
        
        if let timeout = dict["screenLockTimeout"] as? TimeInterval {
            screenLockTimeout = timeout
        }
        
        if let keepAwake = dict["keepScreenAwakeInHapticMode"] as? Bool {
            keepScreenAwakeInHapticMode = keepAwake
        }
    }
}

// MARK: - Navigation State Models

/// Codable model for persisting navigation route state
struct NavigationRouteState: Codable {
    let destinationName: String
    let destinationLatitude: Double
    let destinationLongitude: Double
    let totalDistance: Double
    let estimatedTravelTime: TimeInterval
    let routeSteps: [RouteStepState]
    let currentStepIndex: Int
    
    init(from route: MKRoute, currentStepIndex: Int = 0, destinationName: String = "") {
        self.destinationName = destinationName
        self.destinationLatitude = route.polyline.coordinate.latitude
        self.destinationLongitude = route.polyline.coordinate.longitude
        self.totalDistance = route.distance
        self.estimatedTravelTime = route.expectedTravelTime
        self.routeSteps = route.steps.map { RouteStepState(from: $0) }
        self.currentStepIndex = currentStepIndex
    }
}

/// Codable model for persisting route step state
struct RouteStepState: Codable {
    let instructions: String
    let distance: Double
    let transportType: Int // MKDirectionsTransportType raw value
    
    init(from step: MKRoute.Step) {
        self.instructions = step.instructions
        self.distance = step.distance
        self.transportType = Int(step.transportType.rawValue)
    }
}

// MARK: - NavigationMode Extension

extension NavigationMode: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .visual:
            return "visual"
        case .haptic:
            return "haptic"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "visual":
            self = .visual
        case "haptic":
            self = .haptic
        default:
            return nil
        }
    }
}

// MARK: - MKDirectionsTransportType Extension

extension MKDirectionsTransportType {
    init(from rawValue: Int) {
        switch rawValue {
        case 1:
            self = .automobile
        case 2:
            self = .walking
        case 4:
            self = .transit
        default:
            self = .walking
        }
    }
} 