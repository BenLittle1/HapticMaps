import CoreLocation
import Foundation
import Combine
import UIKit

// MARK: - Location Errors

enum LocationError: Error, LocalizedError {
    case permissionDenied
    case permissionRestricted
    case locationUnavailable
    case networkError
    case gpsSignalLost
    case accuracyTooLow
    case staleLocation
    case backgroundLocationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is denied. Please enable location services in Settings."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Your location is currently unavailable."
        case .networkError:
            return "Network error while getting location. Please check your connection."
        case .gpsSignalLost:
            return "GPS signal lost. Please ensure you have a clear view of the sky."
        case .accuracyTooLow:
            return "Location accuracy is too low for navigation."
        case .staleLocation:
            return "Location data is outdated. Please wait for updated GPS signal."
        case .backgroundLocationNotAvailable:
            return "Background location is not available. Please enable 'Always' location access for navigation."
        }
    }
    
    var recoveryOptions: [LocationErrorRecovery] {
        switch self {
        case .permissionDenied:
            return [.openSettings, .requestPermission]
        case .permissionRestricted:
            return [.contactSupport]
        case .locationUnavailable, .gpsSignalLost:
            return [.retry, .moveToOpenArea]
        case .networkError:
            return [.retry, .checkConnection]
        case .accuracyTooLow:
            return [.retry, .moveToOpenArea]
        case .staleLocation:
            return [.retry, .waitForUpdate]
        case .backgroundLocationNotAvailable:
            return [.openSettings, .requestAlwaysPermission]
        }
    }
}

enum LocationErrorRecovery {
    case openSettings
    case requestPermission
    case requestAlwaysPermission
    case retry
    case moveToOpenArea
    case checkConnection
    case waitForUpdate
    case contactSupport
    
    var title: String {
        switch self {
        case .openSettings:
            return "Open Settings"
        case .requestPermission:
            return "Grant Permission"
        case .requestAlwaysPermission:
            return "Enable Always Access"
        case .retry:
            return "Try Again"
        case .moveToOpenArea:
            return "Move to Open Area"
        case .checkConnection:
            return "Check Connection"
        case .waitForUpdate:
            return "Wait for GPS"
        case .contactSupport:
            return "Contact Support"
        }
    }
}

class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationUpdating: Bool = false
    @Published var isBackgroundLocationEnabled: Bool = false
    @Published var hasRequestedAlwaysPermission: Bool = false
    @Published var locationError: LocationError?
    @Published var isGPSSignalStrong: Bool = true
    @Published var locationAccuracy: CLLocationAccuracy = 0
    
    private let locationManager: CLLocationManager
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var permissionMonitoringTimer: Timer?
    private var gpsSignalMonitoringTimer: Timer?
    private var isInBackground: Bool = false
    private var lastKnownGoodLocation: CLLocation?
    private var locationUpdateRetryCount: Int = 0
    private let maxRetryCount: Int = 3
    private let gpsSignalLossThreshold: TimeInterval = 30.0 // seconds
    private var lastLocationUpdateTime: Date = Date()
    
    // Settings redirect support
    private var pendingLocationAlert: UIAlertController?
    
    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
        setupBackgroundSupport()
        startGPSSignalMonitoring()
    }
    
    // For dependency injection in tests
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        setupLocationManager()
        setupBackgroundSupport()
        startGPSSignalMonitoring()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        authorizationStatus = locationManager.authorizationStatus
        updateBackgroundLocationStatus()
        configureBackgroundLocationUpdates()
    }
    
    private func setupBackgroundSupport() {
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Start permission monitoring
        startPermissionMonitoring()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPermissionMonitoring()
        stopGPSSignalMonitoring()
        endBackgroundTaskIfNeeded()
        dismissPendingAlert()
    }
    
    func requestLocationPermission() {
        clearLocationError()
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Show comprehensive error handling with settings redirect
            handleLocationPermissionDenied()
        case .authorizedWhenInUse:
            // Request always authorization for background navigation
            requestAlwaysPermissionIfNeeded()
        case .authorizedAlways:
            // Already have the best permission
            break
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestAlwaysPermissionIfNeeded() {
        guard !hasRequestedAlwaysPermission else { return }
        hasRequestedAlwaysPermission = true
        locationManager.requestAlwaysAuthorization()
    }
    
    func startLocationUpdates() {
        clearLocationError()
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            locationError = .permissionDenied
            requestLocationPermission()
            return
        }
        
        guard !isLocationUpdating else { return }
        
        locationManager.startUpdatingLocation()
        isLocationUpdating = true
        locationUpdateRetryCount = 0
        lastLocationUpdateTime = Date()
    }
    
    func stopLocationUpdates() {
        guard isLocationUpdating else { return }
        
        locationManager.stopUpdatingLocation()
        isLocationUpdating = false
        clearLocationError()
    }
    
    // MARK: - Error Handling and Recovery
    
    private func handleLocationPermissionDenied() {
        let error: LocationError = authorizationStatus == .restricted ? .permissionRestricted : .permissionDenied
        locationError = error
        showLocationErrorAlert(error: error)
    }
    
    private func showLocationErrorAlert(error: LocationError) {
        dismissPendingAlert()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            let alert = UIAlertController(
                title: "Location Access Required",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            // Add recovery options
            for recovery in error.recoveryOptions {
                let action = UIAlertAction(title: recovery.title, style: .default) { _ in
                    self.handleLocationErrorRecovery(recovery)
                }
                alert.addAction(action)
            }
            
            // Add cancel option
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.pendingLocationAlert = nil
            }
            alert.addAction(cancelAction)
            
            self.pendingLocationAlert = alert
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func handleLocationErrorRecovery(_ recovery: LocationErrorRecovery) {
        pendingLocationAlert = nil
        
        switch recovery {
        case .openSettings:
            openLocationSettings()
        case .requestPermission:
            requestLocationPermission()
        case .requestAlwaysPermission:
            requestAlwaysPermissionIfNeeded()
        case .retry:
            retryLocationUpdate()
        case .moveToOpenArea:
            showMoveToOpenAreaGuidance()
        case .checkConnection:
            showNetworkCheckGuidance()
        case .waitForUpdate:
            showWaitForGPSGuidance()
        case .contactSupport:
            showContactSupportInfo()
        }
    }
    
    private func openLocationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func retryLocationUpdate() {
        guard locationUpdateRetryCount < maxRetryCount else {
            locationError = .locationUnavailable
            return
        }
        
        locationUpdateRetryCount += 1
        
        // Stop and restart location updates with a brief delay
        stopLocationUpdates()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startLocationUpdates()
        }
    }
    
    private func showMoveToOpenAreaGuidance() {
        showGuidanceAlert(
            title: "Improve GPS Signal",
            message: "For better location accuracy, try moving to an open area with a clear view of the sky. Avoid areas near tall buildings or under cover."
        )
    }
    
    private func showNetworkCheckGuidance() {
        showGuidanceAlert(
            title: "Check Network Connection",
            message: "Location services may require an internet connection. Please check your WiFi or cellular connection and try again."
        )
    }
    
    private func showWaitForGPSGuidance() {
        showGuidanceAlert(
            title: "Waiting for GPS Signal",
            message: "Your device is acquiring GPS signal. This may take a few moments, especially when starting from a new location."
        )
    }
    
    private func showContactSupportInfo() {
        showGuidanceAlert(
            title: "Contact Support",
            message: "Location access is restricted on this device. This may be due to parental controls or device management policies. Please contact your device administrator or support for assistance."
        )
    }
    
    private func showGuidanceAlert(title: String, message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default)
            alert.addAction(okAction)
            
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func dismissPendingAlert() {
        pendingLocationAlert?.dismiss(animated: false)
        pendingLocationAlert = nil
    }
    
    private func clearLocationError() {
        locationError = nil
    }
    
    // MARK: - GPS Signal Monitoring
    
    private func startGPSSignalMonitoring() {
        gpsSignalMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkGPSSignalHealth()
        }
    }
    
    private func stopGPSSignalMonitoring() {
        gpsSignalMonitoringTimer?.invalidate()
        gpsSignalMonitoringTimer = nil
    }
    
    private func checkGPSSignalHealth() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastLocationUpdateTime)
        
        // Check if we haven't received location updates for too long
        if isLocationUpdating && timeSinceLastUpdate > gpsSignalLossThreshold {
            if isGPSSignalStrong {
                isGPSSignalStrong = false
                locationError = .gpsSignalLost
                
                // Post notification for UI to handle GPS signal loss
                NotificationCenter.default.post(
                    name: NSNotification.Name("GPSSignalLost"),
                    object: nil,
                    userInfo: ["timeSinceLastUpdate": timeSinceLastUpdate]
                )
            }
        } else if !isGPSSignalStrong && timeSinceLastUpdate < 10.0 {
            isGPSSignalStrong = true
            clearLocationError()
            
            // Post notification for UI to handle GPS signal recovery
            NotificationCenter.default.post(
                name: NSNotification.Name("GPSSignalRecovered"),
                object: nil
            )
        }
    }
    
    // MARK: - Background Support Methods
    
    @objc private func appDidEnterBackground() {
        isInBackground = true
        beginBackgroundTaskIfNeeded()
        
        // Adjust location accuracy for background use
        if isLocationUpdating {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 10.0 // Less frequent updates
        }
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        endBackgroundTaskIfNeeded()
        
        // Restore foreground accuracy
        if isLocationUpdating {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 5.0
        }
        
        // Check if permissions have changed while in background
        checkPermissionChanges()
    }
    
    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier == .invalid else { return }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LocationUpdates") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }
    
    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
    
    private func startPermissionMonitoring() {
        // Check permissions every 30 seconds while app is active
        permissionMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkPermissionChanges()
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionMonitoringTimer?.invalidate()
        permissionMonitoringTimer = nil
    }
    
    private func checkPermissionChanges() {
        let currentStatus = locationManager.authorizationStatus
        
        if currentStatus != authorizationStatus {
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                self.updateBackgroundLocationStatus()
            }
            
            // Handle permission downgrades
            if currentStatus == .denied || currentStatus == .restricted {
                DispatchQueue.main.async {
                    self.showLocationSettingsAlert()
                }
            }
        }
    }
    
    private func updateBackgroundLocationStatus() {
        isBackgroundLocationEnabled = authorizationStatus == .authorizedAlways
        configureBackgroundLocationUpdates()
    }
    
    private func configureBackgroundLocationUpdates() {
        // Only enable background location updates if we have always permission
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.pausesLocationUpdatesAutomatically = true
        }
    }
    
    private func showLocationSettingsAlert() {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("LocationPermissionDenied"),
            object: nil,
            userInfo: ["authorizationStatus": authorizationStatus.rawValue]
        )
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Reset retry count on successful location update
        locationUpdateRetryCount = 0
        
        // Only update if the location is recent and accurate
        let locationAge = -location.timestamp.timeIntervalSinceNow
        let isRecentLocation = locationAge < 5.0
        let isAccurateLocation = location.horizontalAccuracy < 100
        
        if isRecentLocation && isAccurateLocation {
            // Store last known good location
            lastKnownGoodLocation = location
            clearLocationError()
            
            DispatchQueue.main.async {
                self.currentLocation = location
                self.locationAccuracy = location.horizontalAccuracy
                self.lastLocationUpdateTime = Date()
                
                // Clear any GPS signal loss errors since we got a good location
                if self.locationError == .gpsSignalLost {
                    self.clearLocationError()
                }
            }
        } else {
            // Handle poor quality location data
            if !isAccurateLocation && location.horizontalAccuracy > 500 {
                DispatchQueue.main.async {
                    self.locationError = .accuracyTooLow
                }
            } else if !isRecentLocation {
                DispatchQueue.main.async {
                    self.locationError = .staleLocation
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        guard let clError = error as? CLError else {
            DispatchQueue.main.async {
                self.locationError = .locationUnavailable
            }
            return
        }
        
        DispatchQueue.main.async {
            switch clError.code {
            case .denied:
                self.locationError = .permissionDenied
                self.stopLocationUpdates()
                self.handleLocationPermissionDenied()
            case .locationUnknown:
                self.locationError = .locationUnavailable
                // Don't stop updates immediately - try to recover
                self.attemptLocationRecovery()
            case .network:
                self.locationError = .networkError
                self.attemptLocationRecovery()
            case .headingFailure:
                // Heading errors don't affect location, continue
                break
            case .rangingUnavailable, .rangingFailure:
                // Ranging errors don't affect basic location, continue
                break
            @unknown default:
                self.locationError = .locationUnavailable
                self.attemptLocationRecovery()
            }
        }
    }
    
    private func attemptLocationRecovery() {
        guard locationUpdateRetryCount < maxRetryCount else {
            stopLocationUpdates()
            return
        }
        
        // Retry with exponential backoff
        let delay = pow(2.0, Double(locationUpdateRetryCount))
        locationUpdateRetryCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isLocationUpdating else { return }
            
            // Restart location updates
            self.locationManager.stopUpdatingLocation()
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted, can start location updates if requested
            break
        case .denied, .restricted:
            // Permission denied, stop any ongoing updates
            stopLocationUpdates()
        case .notDetermined:
            // Initial state, no action needed
            break
        @unknown default:
            break
        }
    }
}