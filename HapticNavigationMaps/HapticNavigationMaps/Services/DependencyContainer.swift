import Foundation
import CoreLocation
import Combine
import UIKit

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
    @Published private(set) var backgroundTaskManager: BackgroundTaskManager?
    @Published private(set) var performanceMonitor: PerformanceMonitor?
    
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
            
            // Initialize optional services (if available)
            initializeOptionalServices()
            
            // Initialize ViewModels
            try await initializeViewModels()
            
            // Setup service integrations
            setupServiceIntegrations()
            
            // Start performance monitoring (if available)
            startPerformanceMonitoring()
            
            isInitialized = true
            initializationError = nil
            
            print("DependencyContainer: Successfully initialized all services")
            
        } catch {
            initializationError = error
            isInitialized = false
            print("DependencyContainer: Initialization failed with error: \(error)")
            throw error
        }
    }
    
    /// Cleanup all services and reset container state
    func cleanup() async {
        print("DependencyContainer: Starting cleanup...")
        
        // Stop all services in reverse order of initialization
        
        // 1. Stop navigation engine and location updates
        navigationEngine?.stopNavigation()
        locationService?.stopLocationUpdates()
        
        // 2. Clear background tasks
        backgroundTaskManager?.endAllTasks()
        
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
        
        // 8. Stop performance monitoring
        performanceMonitor?.stopMonitoring()
        performanceMonitor = nil
        
        // 9. Clear all publishers and reset state
        cancellables.removeAll()
        isInitialized = false
        initializationError = nil
        
        print("DependencyContainer: Cleanup completed")
    }
    
    // MARK: - Private Initialization Methods
    
    private func initializeCoreServices() async throws {
        // Initialize UserPreferences (no dependencies)
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
    
    private func initializeOptionalServices() {
        // Initialize BackgroundTaskManager (real implementation)
        backgroundTaskManager = BackgroundTaskManager.shared
        print("BackgroundTaskManager initialized")
        
        // Initialize PerformanceMonitor (real implementation)
        performanceMonitor = PerformanceMonitor.shared
        print("PerformanceMonitor initialized")
    }
    
    private func initializeViewModels() async throws {
        // Initialize SearchViewModel with dependencies
        searchViewModel = SearchViewModel(searchService: searchService)
        
        // Initialize NavigationViewModel with dependencies
        navigationViewModel = NavigationViewModel(navigationEngine: navigationEngine)
    }
    
    private func setupServiceIntegrations() {
        // Set up basic service connections
        // Note: More complex publisher integrations can be added when services support them
        
        // Basic optimization based on app state
        print("DependencyContainer: Service integrations initialized")
    }
    
    private func optimizeServicesForTaskLoad(_ taskCount: Int) {
        // If we have many background tasks, optimize location updates
        if taskCount >= 2 {
            // More conservative location updates when many tasks are running
            print("High background task load detected (\(taskCount)), optimizing location service")
        }
    }
     
     private func startPerformanceMonitoring() {
         guard let performanceMonitor = performanceMonitor else {
             print("PerformanceMonitor not available - skipping performance monitoring")
             return
         }
         
         if let backgroundTaskManager = backgroundTaskManager {
             performanceMonitor.startMonitoring(
                 locationService: locationService,
                 hapticService: hapticService,
                 backgroundTaskManager: backgroundTaskManager
             )
         }
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
    
    /// Get user preferences with initialization check
    func getUserPreferences() throws -> UserPreferences {
        guard isInitialized, let preferences = userPreferences else {
            throw DependencyError.serviceNotInitialized("UserPreferences")
        }
        return preferences
    }
    
    // MARK: - App Lifecycle Handling
    
    func handleAppBecomeActive() async {
        // Resume haptic engine if needed
        if hapticService.isHapticCapable && hapticService.engineState != .running {
            do {
                try hapticService.initializeHapticEngine()
            } catch {
                print("Failed to resume haptic engine: \(error)")
            }
        }
        
        print("DependencyContainer: App became active - services resumed")
    }
    
    func handleAppEnterBackground() async {
        // Stop haptic services for background operation
        hapticService?.stopAllHaptics()
        
        print("DependencyContainer: App entered background - services optimized")
    }
    
    func handleAppTermination() async {
        // Cleanup before termination
        await cleanup()
        
        print("DependencyContainer: App will terminate - final cleanup completed")
    }
    
    // MARK: - ViewModels as Dependencies
    
    /// Computed property to provide dependencies to views
    var dependencies: DependencyContainer {
        return self
    }
}

// MARK: - Dependency Errors

enum DependencyError: LocalizedError {
    case serviceNotInitialized(String)
    case initializationFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized(let serviceName):
            return "Service \(serviceName) is not initialized"
        case .initializationFailed(let serviceName, let error):
            return "Failed to initialize \(serviceName): \(error.localizedDescription)"
        }
    }
} 