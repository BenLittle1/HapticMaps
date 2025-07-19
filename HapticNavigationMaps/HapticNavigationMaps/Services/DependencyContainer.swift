import Foundation
import CoreLocation
import Combine

/// Dependency injection container for managing service lifecycles and dependencies
@MainActor
class DependencyContainer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Services
    @Published private(set) var locationService: LocationService!
    @Published private(set) var hapticService: HapticNavigationService!
    @Published private(set) var searchService: SearchService!
    @Published private(set) var navigationEngine: NavigationEngine!
    @Published private(set) var userPreferences: UserPreferences!
    
    // MARK: - ViewModels
    @Published private(set) var searchViewModel: SearchViewModel!
    @Published private(set) var navigationViewModel: NavigationViewModel!
    
    // MARK: - Lifecycle State
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var initializationError: Error?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Private init to enforce singleton
    }
    
    // MARK: - Initialization
    
    /// Initialize all services with proper dependency injection
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Initialize core services first
            try await initializeCoreServices()
            
            // Initialize dependent services
            try await initializeDependentServices()
            
            // Initialize ViewModels
            try await initializeViewModels()
            
            // Setup service integrations
            setupServiceIntegrations()
            
            isInitialized = true
            initializationError = nil
            
        } catch {
            initializationError = error
            throw error
        }
    }
    
    /// Cleanup all services and reset state
    func cleanup() async {
        // Stop all active services in proper order
        
        // 1. Stop navigation first (this will handle haptic cleanup)
        navigationEngine?.stopNavigation()
        navigationEngine?.cancelRouteCalculation()
        
        // 2. Stop location services  
        locationService?.stopLocationUpdates()
        
        // 3. Stop haptic services
        hapticService?.stopAllHaptics()
        hapticService?.stopNavigationBackgroundTask()
        
        // 4. Cancel all search operations
        searchService?.cancelAllSearches()
        searchViewModel?.cancelSearch()
        
        // 5. Clear ViewModels and reset their state
        searchViewModel = nil
        navigationViewModel = nil
        
        // 6. Save final state to preferences
        userPreferences?.clearNavigationState()
        
        // 7. Reset service references
        navigationEngine = nil
        locationService = nil
        hapticService = nil
        searchService = nil
        userPreferences = nil
        
        // 8. Clear all publishers and reset state
        cancellables.removeAll()
        isInitialized = false
        initializationError = nil
        
        print("DependencyContainer: Cleanup completed")
    }
    
    // MARK: - Private Initialization Methods
    
    private func initializeCoreServices() async throws {
        // Initialize UserPreferences first (no dependencies)
        userPreferences = UserPreferences.shared
        
        // Initialize LocationService (no dependencies)
        locationService = LocationService()
        
        // Initialize HapticService (no dependencies)
        hapticService = HapticNavigationService()
        
        // Try to initialize haptic engine if capable
        if hapticService.isHapticCapable {
            do {
                try hapticService.initializeHapticEngine()
            } catch {
                // Haptic initialization failure is not critical, continue without it
                print("Warning: Failed to initialize haptic engine: \(error)")
            }
        }
        
        // Initialize SearchService (no dependencies)
        searchService = SearchService()
    }
    
    private func initializeDependentServices() async throws {
        // Initialize NavigationEngine with haptic service dependency
        navigationEngine = NavigationEngine(hapticService: hapticService)
    }
    
    private func initializeViewModels() async throws {
        // Initialize SearchViewModel with search service dependency
        searchViewModel = SearchViewModel(searchService: searchService)
        
        // Initialize NavigationViewModel with navigation engine dependency
        navigationViewModel = NavigationViewModel(navigationEngine: navigationEngine)
    }
    
    private func setupServiceIntegrations() {
        // Setup location updates for navigation engine
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.navigationEngine.updateProgress(location: location)
                self?.navigationViewModel.updateProgress(location: location)
            }
            .store(in: &cancellables)
        
        // Setup navigation state persistence
        navigationEngine.$navigationState
            .sink { [weak self] state in
                self?.userPreferences.saveNavigationState(state)
            }
            .store(in: &cancellables)
        
        // Setup haptic mode changes
        userPreferences.$preferredNavigationMode
            .sink { [weak self] mode in
                if case .navigating = self?.navigationEngine.navigationState {
                    self?.navigationEngine.setNavigationMode(mode)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Service Access Methods
    
    /// Get location service with initialization check
    func getLocationService() throws -> LocationService {
        guard isInitialized, let service = locationService else {
            throw DependencyError.serviceNotInitialized("LocationService")
        }
        return service
    }
    
    /// Get haptic service with initialization check
    func getHapticService() throws -> HapticNavigationService {
        guard isInitialized, let service = hapticService else {
            throw DependencyError.serviceNotInitialized("HapticNavigationService")
        }
        return service
    }
    
    /// Get search service with initialization check
    func getSearchService() throws -> SearchService {
        guard isInitialized, let service = searchService else {
            throw DependencyError.serviceNotInitialized("SearchService")
        }
        return service
    }
    
    /// Get navigation engine with initialization check
    func getNavigationEngine() throws -> NavigationEngine {
        guard isInitialized, let engine = navigationEngine else {
            throw DependencyError.serviceNotInitialized("NavigationEngine")
        }
        return engine
    }
    
    /// Get search view model with initialization check
    func getSearchViewModel() throws -> SearchViewModel {
        guard isInitialized, let viewModel = searchViewModel else {
            throw DependencyError.serviceNotInitialized("SearchViewModel")
        }
        return viewModel
    }
    
    /// Get navigation view model with initialization check
    func getNavigationViewModel() throws -> NavigationViewModel {
        guard isInitialized, let viewModel = navigationViewModel else {
            throw DependencyError.serviceNotInitialized("NavigationViewModel")
        }
        return viewModel
    }
    
    // MARK: - Background Support
    
    /// Setup background support for navigation
    func setupBackgroundSupport() {
        // Request background location permission if navigation is active
        if case .navigating = navigationEngine?.navigationState {
            locationService?.requestAlwaysPermissionIfNeeded()
            hapticService?.startNavigationBackgroundTask()
        }
    }
    
    /// Cleanup background support
    func cleanupBackgroundSupport() {
        hapticService?.stopNavigationBackgroundTask()
    }
}

// MARK: - Dependency Error

enum DependencyError: LocalizedError {
    case serviceNotInitialized(String)
    case initializationFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized(let serviceName):
            return "Service not initialized: \(serviceName)"
        case .initializationFailed(let serviceName, let error):
            return "Failed to initialize \(serviceName): \(error.localizedDescription)"
        }
    }
}

// MARK: - App Lifecycle Integration

extension DependencyContainer {
    
    /// Handle app becoming active
    func handleAppBecomeActive() async {
        // Resume location updates if needed
        if case .navigating = navigationEngine?.navigationState {
            locationService?.startLocationUpdates()
        }
        
        // Resume haptic engine if needed
        if hapticService?.isHapticModeEnabled == true {
            do {
                try hapticService?.initializeHapticEngine()
            } catch {
                print("Failed to resume haptic engine: \(error)")
            }
        }
    }
    
    /// Handle app entering background
    func handleAppEnterBackground() async {
        // Setup background support if navigation is active
        if case .navigating = navigationEngine?.navigationState {
            setupBackgroundSupport()
        } else {
            // Stop location updates to save battery
            locationService?.stopLocationUpdates()
            cleanupBackgroundSupport()
        }
    }
    
    /// Handle app termination
    func handleAppTermination() async {
        await cleanup()
    }
} 