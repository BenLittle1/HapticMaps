import SwiftUI
import Combine
import UIKit

/// App coordinator responsible for managing app lifecycle and service initialization
@MainActor
class AppCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var initializationError: Error?
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Dependencies
    private let dependencyContainer = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle State
    private var hasAttemptedInitialization = false
    
    init() {
        setupAppLifecycleObservers()
        setupDependencyObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - App Initialization
    
    /// Initialize the app with all services and dependencies
    func initializeApp() async {
        guard !hasAttemptedInitialization else { return }
        hasAttemptedInitialization = true
        
        isLoading = true
        initializationError = nil
        
        do {
            // Initialize dependency container
            try await dependencyContainer.initialize()
            
            // Setup initial permissions
            await setupInitialPermissions()
            
            // Restore previous navigation state if applicable
            await restoreNavigationState()
            
            isInitialized = true
            
        } catch {
            initializationError = error
            print("App initialization failed: \(error)")
        }
        
        isLoading = false
    }
    
    /// Reset app state and reinitialize
    func resetAndReinitialize() async {
        hasAttemptedInitialization = false
        isInitialized = false
        
        await dependencyContainer.cleanup()
        await initializeApp()
    }
    
    // MARK: - Private Setup Methods
    
    private func setupAppLifecycleObservers() {
        // App did become active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppBecomeActive()
            }
        }
        
        // App will enter background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppEnterBackground()
            }
        }
        
        // App will terminate
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppTermination()
            }
        }
    }
    
    private func setupDependencyObservers() {
        // Monitor dependency container initialization
        dependencyContainer.$isInitialized
            .sink { [weak self] isInitialized in
                if isInitialized {
                    self?.isInitialized = true
                }
            }
            .store(in: &cancellables)
        
        // Monitor dependency container errors
        dependencyContainer.$initializationError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.initializationError = error
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialPermissions() async {
        // Request location permission on app launch
        do {
            let locationService = try dependencyContainer.getLocationService()
            
            switch locationService.authorizationStatus {
            case .notDetermined:
                locationService.requestLocationPermission()
            case .authorizedWhenInUse, .authorizedAlways:
                locationService.startLocationUpdates()
            default:
                break
            }
        } catch {
            print("Failed to setup location permissions: \(error)")
        }
    }
    
    private func restoreNavigationState() async {
        // Restore previous navigation state from UserPreferences
        let preferences = dependencyContainer.userPreferences
        
        if let _ = preferences?.lastNavigationRoute,
           let _ = preferences?.lastNavigationMode {
            
            // Try to restore navigation if there was an active session
            print("Found previous navigation state, ready to restore if needed")
            // Note: Actual restoration would happen when user chooses to continue
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppBecomeActive() async {
        guard isInitialized else { return }
        
        await dependencyContainer.handleAppBecomeActive()
        
        // Additional app-specific logic when becoming active
        print("App became active")
    }
    
    private func handleAppEnterBackground() async {
        guard isInitialized else { return }
        
        await dependencyContainer.handleAppEnterBackground()
        
        // Additional app-specific logic when entering background
        print("App entered background")
    }
    
    private func handleAppTermination() async {
        await dependencyContainer.handleAppTermination()
        
        // Save any final state before termination
        print("App will terminate")
    }
    
    // MARK: - Service Access
    
    /// Get the dependency container (for use in views)
    var dependencies: DependencyContainer {
        return dependencyContainer
    }
    
    // MARK: - Navigation State Management
    
    /// Check if the app should show onboarding
    var shouldShowOnboarding: Bool {
        // Show onboarding if location permission not granted
        guard let locationService = dependencyContainer.locationService else {
            return true
        }
        
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return false
        default:
            return true
        }
    }
    
    /// Check if navigation is currently active
    var isNavigationActive: Bool {
        guard let navigationEngine = dependencyContainer.navigationEngine else {
            return false
        }
        
        switch navigationEngine.navigationState {
        case .navigating:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Handling

extension AppCoordinator {
    
    /// Handle initialization errors with user-friendly messages
    var initializationErrorMessage: String {
        guard let error = initializationError else {
            return ""
        }
        
        if let dependencyError = error as? DependencyError {
            switch dependencyError {
            case .serviceNotInitialized(let serviceName):
                return "Failed to initialize \(serviceName). Please restart the app."
            case .initializationFailed(let serviceName, _):
                return "Failed to start \(serviceName). Some features may not work properly."
            }
        }
        
        return "Failed to initialize the app. Please check your network connection and try again."
    }
    
    /// Retry initialization after error
    func retryInitialization() async {
        initializationError = nil
        await resetAndReinitialize()
    }
} 