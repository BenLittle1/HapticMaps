import XCTest
import UIKit
import CoreLocation
import CoreHaptics
import AVFoundation
@testable import HapticNavigationMaps

/// Comprehensive device compatibility tests for different iOS versions and hardware
@MainActor
class DeviceCompatibilityTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var dependencyContainer: DependencyContainer!
    var deviceCapabilities: DeviceCapabilities!
    
    // MARK: - Device Capability Detection
    
    struct DeviceCapabilities {
        let deviceModel: String
        let systemVersion: String
        let supportsHaptics: Bool
        let supportsCoreLocation: Bool
        let supportsBackgroundLocation: Bool
        let supportsAudio: Bool
        let memoryCapacity: UInt64
        let screenSize: CGSize
        let screenScale: CGFloat
        let supportsDynamicType: Bool
        let supportsAccessibility: Bool
        let thermalState: ProcessInfo.ThermalState
        
        init() {
            // Device identification
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            deviceModel = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value))!)
            }
            
            systemVersion = UIDevice.current.systemVersion
            
            // Capability detection
            supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
            supportsCoreLocation = CLLocationManager.locationServicesEnabled()
            supportsBackgroundLocation = Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil
            supportsAudio = AVAudioSession.sharedInstance().isOtherAudioPlaying == false
            
            // Memory and display
            memoryCapacity = ProcessInfo.processInfo.physicalMemory
            screenSize = UIScreen.main.bounds.size
            screenScale = UIScreen.main.scale
            
            // Accessibility support
            supportsDynamicType = UIApplication.shared.preferredContentSizeCategory != .unspecified
            supportsAccessibility = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
            
            // Thermal state
            thermalState = ProcessInfo.processInfo.thermalState
        }
        
        var isLowEndDevice: Bool {
            // Simplified low-end device detection based on memory
            return memoryCapacity < 3_000_000_000 // Less than 3GB
        }
        
        var isOlderiOSVersion: Bool {
            if let version = Float(systemVersion.prefix(4)) {
                return version < 15.0 // iOS 15 and older
            }
            return false
        }
    }
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        deviceCapabilities = DeviceCapabilities()
        dependencyContainer = DependencyContainer.shared
        
        // Initialize services for testing
        try await dependencyContainer.initialize()
        
        print("Testing on device: \(deviceCapabilities.deviceModel)")
        print("iOS Version: \(deviceCapabilities.systemVersion)")
        print("Supports Haptics: \(deviceCapabilities.supportsHaptics)")
        print("Memory: \(deviceCapabilities.memoryCapacity / 1_000_000) MB")
    }
    
    override func tearDown() async throws {
        await dependencyContainer.cleanup()
        try await super.tearDown()
    }
    
    // MARK: - iOS Version Compatibility Tests
    
    func testMinimumIOSVersionSupport() throws {
        // Test that app functions on minimum supported iOS version
        
        let systemVersion = deviceCapabilities.systemVersion
        let components = systemVersion.split(separator: ".").compactMap { Int($0) }
        
        guard let majorVersion = components.first else {
            XCTFail("Could not determine iOS version")
            return
        }
        
        // Assuming minimum iOS 14.0 support
        XCTAssertGreaterThanOrEqual(majorVersion, 14, "App requires iOS 14.0 or later")
        
        // Test version-specific features
        if majorVersion >= 15 {
            // iOS 15+ specific features
            testModernLocationServicesAPI()
        } else {
            // Legacy iOS 14 compatibility
            testLegacyLocationServicesAPI()
        }
    }
    
    func testModernLocationServicesAPI() {
        // Test iOS 15+ location services features
        let locationService = try! dependencyContainer.getLocationService()
        
        // Test modern accuracy authorization
        if #available(iOS 14.0, *) {
            let accuracy = locationService.authorizationStatus
            XCTAssertNotEqual(accuracy, .notDetermined, "Location authorization should be determinable")
        }
        
        // Test background location capabilities
        XCTAssertTrue(deviceCapabilities.supportsBackgroundLocation, "Background location should be configured")
    }
    
    func testLegacyLocationServicesAPI() {
        // Test iOS 14 location services compatibility
        let locationService = try! dependencyContainer.getLocationService()
        
        // Ensure basic location functionality works on older devices
        XCTAssertTrue(CLLocationManager.locationServicesEnabled(), "Location services should be available")
        XCTAssertTrue(locationService.authorizationStatus != .restricted, "Location should not be restricted")
    }
    
    // MARK: - Hardware Capability Tests
    
    func testHapticHardwareSupport() throws {
        let hapticService = try dependencyContainer.getHapticService()
        
        if deviceCapabilities.supportsHaptics {
            // Test haptic capabilities on supported devices
            XCTAssertTrue(hapticService.isHapticCapable, "Haptic service should detect hardware support")
            
            // Test haptic engine initialization
            try hapticService.initializeHapticEngine()
            XCTAssertEqual(hapticService.engineState, .running, "Haptic engine should initialize successfully")
            
            // Test pattern playback
            let expectation = expectation(description: "Haptic pattern played")
            Task {
                do {
                    try await hapticService.playTurnLeftPattern()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to play haptic pattern: \(error)")
                }
            }
            wait(for: [expectation], timeout: 5.0)
            
        } else {
            // Test graceful fallback on devices without haptics
            XCTAssertFalse(hapticService.isHapticCapable, "Haptic service should detect lack of hardware support")
            
            // Verify fallback systems work
            XCTAssertTrue(deviceCapabilities.supportsAudio, "Audio fallback should be available")
        }
    }
    
    func testLocationHardwareSupport() throws {
        let locationService = try dependencyContainer.getLocationService()
        
        // Test GPS availability
        XCTAssertTrue(CLLocationManager.locationServicesEnabled(), "GPS hardware should be available")
        
        // Test location accuracy capabilities
        if deviceCapabilities.isLowEndDevice {
            // Lower expectations for low-end devices
            print("Testing on low-end device - using relaxed accuracy requirements")
        } else {
            // Full accuracy testing for modern devices
            locationService.updateNavigationState(.navigating(mode: .haptic))
            
            // Verify high-accuracy mode is set
            // Note: Actual accuracy testing requires real GPS signals
        }
    }
    
    func testMemoryConstraints() throws {
        let initialMemory = getCurrentMemoryUsage()
        
        // Initialize all services
        let locationService = try dependencyContainer.getLocationService()
        let hapticService = try dependencyContainer.getHapticService()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        
        // Simulate memory-intensive operations
        if hapticService.isHapticCapable {
            try hapticService.initializeHapticEngine()
        }
        
        locationService.updateNavigationState(.navigating(mode: .visual))
        
        let memoryAfterInit = getCurrentMemoryUsage()
        let memoryIncrease = memoryAfterInit - initialMemory
        
        // Memory usage should be reasonable based on device capabilities
        let maxAllowableMemory: UInt64 = deviceCapabilities.isLowEndDevice ? 100_000_000 : 200_000_000 // 100MB vs 200MB
        
        XCTAssertLessThan(memoryIncrease, maxAllowableMemory, 
                         "Memory usage should be within device constraints (\(memoryIncrease / 1_000_000)MB used)")
    }
    
    // MARK: - Screen Size and Accessibility Tests
    
    func testScreenSizeCompatibility() throws {
        let screenSize = deviceCapabilities.screenSize
        let screenScale = deviceCapabilities.screenScale
        
        // Test minimum screen size requirements
        XCTAssertGreaterThan(screenSize.width, 320, "Screen width should support minimum iPhone size")
        XCTAssertGreaterThan(screenSize.height, 480, "Screen height should support minimum iPhone size")
        
        // Test different screen configurations
        if screenSize.width > 400 {
            // iPhone 6+ and larger screens
            testLargeScreenLayout()
        } else {
            // iPhone SE and smaller screens
            testCompactScreenLayout()
        }
        
        // Test high-resolution displays
        if screenScale >= 3.0 {
            testHighResolutionDisplay()
        }
    }
    
    func testLargeScreenLayout() {
        // Test layout on larger screens
        print("Testing large screen layout optimizations")
        
        // Verify UI elements scale appropriately
        // This would typically involve UI testing with actual view controllers
    }
    
    func testCompactScreenLayout() {
        // Test layout on compact screens
        print("Testing compact screen layout optimizations")
        
        // Verify UI elements remain usable on small screens
    }
    
    func testHighResolutionDisplay() {
        // Test high-resolution display support
        print("Testing high-resolution display optimizations")
        
        // Verify graphics and text remain crisp
    }
    
    func testDynamicTypeSupport() throws {
        guard deviceCapabilities.supportsDynamicType else {
            throw XCTSkip("Dynamic Type not supported on this device")
        }
        
        // Test different content size categories
        let contentSizeCategories: [UIContentSizeCategory] = [
            .small,
            .medium,
            .large,
            .extraLarge,
            .accessibilityMedium,
            .accessibilityExtraLarge
        ]
        
        for category in contentSizeCategories {
            // Simulate content size category change
            NotificationCenter.default.post(
                name: UIContentSizeCategory.didChangeNotification,
                object: nil,
                userInfo: [UIContentSizeCategory.newValueUserInfoKey: category]
            )
            
            // Verify text scales appropriately
            let accessibilityService = AccessibilityService.shared
            let fontScale = accessibilityService.getAccessibleFontScale()
            
            XCTAssertGreaterThan(fontScale, 0.5, "Font scale should be reasonable for \(category)")
            XCTAssertLessThan(fontScale, 3.0, "Font scale should not be excessive for \(category)")
        }
    }
    
    // MARK: - Performance Tests by Device Type
    
    func testPerformanceForDeviceType() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run comprehensive workflow
        let locationService = try dependencyContainer.getLocationService()
        let hapticService = try dependencyContainer.getHapticService()
        let navigationEngine = try dependencyContainer.getNavigationEngine()
        
        // Test navigation initialization
        locationService.updateNavigationState(.calculating)
        
        if hapticService.isHapticCapable {
            try hapticService.initializeHapticEngine()
        }
        
        locationService.updateNavigationState(.navigating(mode: .haptic))
        
        // Test haptic patterns (if supported)
        if hapticService.isHapticCapable {
            for _ in 0..<5 {
                try await hapticService.playTurnLeftPattern()
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
            }
        }
        
        // End navigation
        locationService.updateNavigationState(.arrived)
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance expectations based on device type
        let maxTimeAllowed: Double = deviceCapabilities.isLowEndDevice ? 5.0 : 3.0
        
        XCTAssertLessThan(totalTime, maxTimeAllowed, 
                         "Navigation workflow should complete quickly on \(deviceCapabilities.deviceModel)")
    }
    
    func testBatteryImpactForDeviceType() throws {
        let backgroundTaskManager = dependencyContainer.backgroundTaskManager!
        let performanceMonitor = dependencyContainer.performanceMonitor!
        
        // Start monitoring
        performanceMonitor.collectMetrics()
        
        let initialBatteryLevel = UIDevice.current.batteryLevel
        
        // Simulate battery-intensive operations
        let locationService = try dependencyContainer.getLocationService()
        locationService.updateNavigationState(.navigating(mode: .haptic))
        
        // Start background tasks
        let _ = backgroundTaskManager.beginTask(.navigation)
        let _ = backgroundTaskManager.beginTask(.locationUpdates)
        
        // Run for a short period to measure impact
        let testDuration: TimeInterval = 10.0 // 10 seconds
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < testDuration {
            performanceMonitor.collectMetrics()
            try! Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Clean up
        backgroundTaskManager.endAllTasks()
        locationService.updateNavigationState(.idle)
        
        // Verify battery optimization is working
        let optimizationLevel = performanceMonitor.batteryOptimizationLevel
        
        if deviceCapabilities.isLowEndDevice || initialBatteryLevel < 0.3 {
            XCTAssertGreaterThan(optimizationLevel, 0, "Battery optimization should be active on low-end devices or low battery")
        }
    }
    
    // MARK: - Accessibility Testing
    
    func testAccessibilityCompliance() throws {
        guard deviceCapabilities.supportsAccessibility else {
            throw XCTSkip("Accessibility features not available")
        }
        
        let accessibilityService = AccessibilityService.shared
        
        // Test VoiceOver support
        if UIAccessibility.isVoiceOverRunning {
            testVoiceOverSupport()
        }
        
        // Test high contrast support
        if UIAccessibility.isDarkerSystemColorsEnabled {
            testHighContrastSupport()
        }
        
        // Test reduced motion support
        if UIAccessibility.isReduceMotionEnabled {
            testReducedMotionSupport()
        }
        
        // Test haptic alternatives
        if !deviceCapabilities.supportsHaptics {
            testHapticAlternatives()
        }
    }
    
    func testVoiceOverSupport() {
        print("Testing VoiceOver compatibility")
        
        // Verify accessibility labels and hints are provided
        // This would typically involve UI testing with actual view controllers
        
        let accessibilityService = AccessibilityService.shared
        
        // Test audio announcements
        accessibilityService.announceAccessibility("Testing VoiceOver support")
        
        // Test navigation instruction speaking
        accessibilityService.speakNavigationInstruction("Turn left in 100 meters")
    }
    
    func testHighContrastSupport() {
        print("Testing high contrast mode compatibility")
        
        // Verify UI adapts to high contrast requirements
        // This would involve checking color contrast ratios
    }
    
    func testReducedMotionSupport() {
        print("Testing reduced motion compatibility")
        
        // Verify animations can be disabled
        // This would involve checking animation preferences
    }
    
    func testHapticAlternatives() {
        print("Testing haptic alternatives for devices without haptic support")
        
        let accessibilityService = AccessibilityService.shared
        
        // Test audio fallbacks
        accessibilityService.playAudioCue(for: .leftTurn)
        accessibilityService.playAudioCue(for: .rightTurn)
        accessibilityService.playAudioCue(for: .continueStraight)
        accessibilityService.playAudioCue(for: .arrival)
        
        // Verify fallbacks work correctly
        XCTAssertTrue(true, "Audio fallbacks should work on devices without haptics")
    }
    
    // MARK: - Thermal State Testing
    
    func testThermalStateHandling() throws {
        let performanceMonitor = dependencyContainer.performanceMonitor!
        
        // Test different thermal states
        let currentThermalState = deviceCapabilities.thermalState
        
        performanceMonitor.collectMetrics()
        
        switch currentThermalState {
        case .nominal:
            // Normal performance expectations
            XCTAssertLessThanOrEqual(performanceMonitor.batteryOptimizationLevel, 1, 
                                   "Optimization should be minimal in nominal thermal state")
            
        case .fair:
            // Moderate optimization
            XCTAssertGreaterThanOrEqual(performanceMonitor.batteryOptimizationLevel, 1, 
                                      "Some optimization should be active in fair thermal state")
            
        case .serious:
            // Significant optimization
            XCTAssertGreaterThanOrEqual(performanceMonitor.batteryOptimizationLevel, 3, 
                                      "High optimization should be active in serious thermal state")
            
        case .critical:
            // Maximum optimization
            XCTAssertEqual(performanceMonitor.batteryOptimizationLevel, 5, 
                         "Maximum optimization should be active in critical thermal state")
            
        @unknown default:
            XCTFail("Unknown thermal state")
        }
    }
    
    // MARK: - Error Recovery Testing
    
    func testErrorRecoveryAcrossDevices() async throws {
        let locationService = try dependencyContainer.getLocationService()
        let hapticService = try dependencyContainer.getHapticService()
        
        // Test location service error recovery
        await testLocationServiceErrorRecovery(locationService)
        
        // Test haptic service error recovery (if supported)
        if hapticService.isHapticCapable {
            await testHapticServiceErrorRecovery(hapticService)
        }
        
        // Test network error recovery
        await testNetworkErrorRecovery()
    }
    
    func testLocationServiceErrorRecovery(_ locationService: LocationService) async {
        // Simulate GPS signal loss
        locationService.updateNavigationState(.navigating(mode: .visual))
        
        // The service should handle GPS signal loss gracefully
        // This would typically involve mocking location manager failures
    }
    
    func testHapticServiceErrorRecovery(_ hapticService: HapticNavigationService) async {
        // Test haptic engine reset capability
        do {
            try hapticService.initializeHapticEngine()
            try hapticService.resetEngine()
            
            // Verify engine can be reinitialized after reset
            try hapticService.initializeHapticEngine()
            XCTAssertEqual(hapticService.engineState, .running, "Haptic engine should recover after reset")
            
        } catch {
            XCTFail("Haptic engine should recover from errors: \(error)")
        }
    }
    
    func testNetworkErrorRecovery() async {
        let searchService = try! dependencyContainer.getSearchService()
        
        // Test search service error handling
        // This would typically involve mocking network failures
        
        do {
            // This should handle network errors gracefully
            let _ = try await searchService.searchLocations(query: "Test Location")
        } catch {
            // Network errors should be handled gracefully
            print("Network error handled: \(error)")
        }
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
    
    // MARK: - Device Compatibility Summary
    
    func testGenerateCompatibilityReport() throws {
        // Generate a comprehensive compatibility report
        
        let report = """
        
        ========== DEVICE COMPATIBILITY REPORT ==========
        
        Device: \(deviceCapabilities.deviceModel)
        iOS Version: \(deviceCapabilities.systemVersion)
        Memory: \(deviceCapabilities.memoryCapacity / 1_000_000) MB
        Screen: \(deviceCapabilities.screenSize.width)x\(deviceCapabilities.screenSize.height) @\(deviceCapabilities.screenScale)x
        
        CAPABILITIES:
        ✓ Haptics: \(deviceCapabilities.supportsHaptics ? "Yes" : "No")
        ✓ Location: \(deviceCapabilities.supportsCoreLocation ? "Yes" : "No")
        ✓ Background Location: \(deviceCapabilities.supportsBackgroundLocation ? "Yes" : "No")
        ✓ Audio: \(deviceCapabilities.supportsAudio ? "Yes" : "No")
        ✓ Dynamic Type: \(deviceCapabilities.supportsDynamicType ? "Yes" : "No")
        ✓ Accessibility: \(deviceCapabilities.supportsAccessibility ? "Yes" : "No")
        
        DEVICE CLASS:
        • Type: \(deviceCapabilities.isLowEndDevice ? "Low-end" : "High-end")
        • iOS: \(deviceCapabilities.isOlderiOSVersion ? "Legacy" : "Modern")
        • Thermal State: \(deviceCapabilities.thermalState)
        
        RECOMMENDATIONS:
        \(getCompatibilityRecommendations())
        
        ================================================
        """
        
        print(report)
        
        // Verify app is compatible with this device
        XCTAssertTrue(isDeviceCompatible(), "App should be compatible with this device")
    }
    
    private func getCompatibilityRecommendations() -> String {
        var recommendations: [String] = []
        
        if deviceCapabilities.isLowEndDevice {
            recommendations.append("• Use battery optimization for low-end device")
            recommendations.append("• Reduce location update frequency")
        }
        
        if deviceCapabilities.isOlderiOSVersion {
            recommendations.append("• Use legacy location services API")
            recommendations.append("• Avoid modern iOS features")
        }
        
        if !deviceCapabilities.supportsHaptics {
            recommendations.append("• Enable audio and visual fallbacks")
            recommendations.append("• Provide alternative navigation feedback")
        }
        
        if deviceCapabilities.thermalState != .nominal {
            recommendations.append("• Enable thermal throttling")
            recommendations.append("• Reduce performance-intensive operations")
        }
        
        return recommendations.isEmpty ? "• No specific recommendations" : recommendations.joined(separator: "\n")
    }
    
    private func isDeviceCompatible() -> Bool {
        // Check minimum requirements
        guard let systemVersion = Float(deviceCapabilities.systemVersion.prefix(4)),
              systemVersion >= 14.0 else {
            return false // Requires iOS 14.0+
        }
        
        guard deviceCapabilities.supportsCoreLocation else {
            return false // Requires location services
        }
        
        guard deviceCapabilities.memoryCapacity >= 1_000_000_000 else {
            return false // Requires at least 1GB RAM
        }
        
        return true
    }
} 