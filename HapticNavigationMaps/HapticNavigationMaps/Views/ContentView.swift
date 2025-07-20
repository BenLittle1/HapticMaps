import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var showingOnboarding = false
    @State private var navigationPath = NavigationPath()
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var showDebugPanel = true
    @State private var lastAuthStatus: CLAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Debug Panel
                if showDebugPanel {
                    LocationDebugPanel()
                        .background(Color.red.opacity(0.1))
                        .border(Color.red, width: 1)
                        .padding(.horizontal)
                }
                
                Group {
                    if shouldShowOnboardingScreen {
                        OnboardingView()
                    } else {
                        MainMapView()
                    }
                }
            }
            .navigationTitle("Haptic Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showDebugPanel ? "Hide Debug" : "Show Debug") {
                        showDebugPanel.toggle()
                    }
                    .font(.caption)
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .settings:
                    NavigationModeSettingsView()
                case .onboarding:
                    OnboardingView()
                }
            }
        }
        .onAppear {
            checkOnboardingStatus()
            checkInitialLocationStatus()
        }
        .onChange(of: dependencies.locationService?.authorizationStatus) { _, status in
            print("🔍 ContentView: Auth status changed to: \(String(describing: status))")
            handleLocationAuthorizationChange(status)
        }
        .onChange(of: dependencies.isInitialized) { _, isInitialized in
            print("🔍 ContentView: Dependencies initialized: \(isInitialized)")
            if isInitialized {
                checkInitialLocationStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Update local state when UserDefaults changes
            hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        }
        // Additional monitoring for location status changes
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            checkLocationStatusPeriodically()
        }
    }
    
    // MARK: - Private Properties
    
    private var shouldShowOnboardingScreen: Bool {
        // Always show onboarding if user hasn't seen it
        if !hasSeenOnboarding {
            return true
        }
        
        // If user has seen onboarding but is being forced to see it again
        return showingOnboarding
    }
    
    // MARK: - Private Methods
    
    private func checkOnboardingStatus() {
        print("🔍 ContentView: Checking onboarding status - hasSeenOnboarding: \(hasSeenOnboarding)")
        if !hasSeenOnboarding {
            showingOnboarding = true
        } else {
            showingOnboarding = false
        }
    }
    
    private func checkInitialLocationStatus() {
        guard dependencies.isInitialized,
              let locationService = dependencies.locationService else {
            print("🔍 ContentView: Dependencies not ready yet")
            return
        }
        
        let currentStatus = locationService.authorizationStatus
        print("🔍 ContentView: Initial location status check: \(currentStatus)")
        
        // If we already have permission and user has seen onboarding, complete it
        if hasSeenOnboarding && (currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways) {
            print("🔍 ContentView: User has permission and has seen onboarding, completing")
            completeOnboarding()
        }
    }
    
    private func checkLocationStatusPeriodically() {
        guard let locationService = dependencies.locationService else { return }
        
        let currentStatus = locationService.authorizationStatus
        
        // Check if status changed
        if currentStatus != lastAuthStatus {
            print("🔍 ContentView: Periodic check - status changed from \(lastAuthStatus) to \(currentStatus)")
            lastAuthStatus = currentStatus
            handleLocationAuthorizationChange(currentStatus)
        }
    }
    
    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus?) {
        guard let status = status else {
            print("🔍 ContentView: Received nil status")
            return
        }
        
        print("🔍 ContentView: Handling auth change: \(status), hasSeenOnboarding: \(hasSeenOnboarding), showingOnboarding: \(showingOnboarding)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("🔍 ContentView: Permission granted, completing onboarding")
            // User granted permission, complete onboarding and transition to main app
            completeOnboarding()
        case .denied, .restricted:
            print("🔍 ContentView: Permission denied/restricted")
            // Permission denied - only show onboarding if user hasn't seen it yet
            if !hasSeenOnboarding {
                showingOnboarding = true
            }
        case .notDetermined:
            print("🔍 ContentView: Permission not determined")
        @unknown default:
            print("🔍 ContentView: Unknown permission status")
        }
    }
    
    private func completeOnboarding() {
        print("🔍 ContentView: Completing onboarding")
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        hasSeenOnboarding = true
        showingOnboarding = false
        
        // Start location updates if we have permission
        if let locationService = dependencies.locationService {
            print("🔍 ContentView: Starting location updates")
            locationService.startLocationUpdates()
        }
    }
}

// MARK: - Location Debug Panel

struct LocationDebugPanel: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var refreshCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🔍 LOCATION DEBUG")
                    .font(.caption.bold())
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Refresh \(refreshCount)") {
                    refreshCount += 1
                    checkLocationNow()
                }
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(3)
            }
            
            HStack {
                Text("Service:")
                Text(dependencies.locationService != nil ? "✅ Created" : "❌ Not Created")
                    .font(.caption.monospaced())
            }
            
            HStack {
                Text("Dependencies:")
                Text(dependencies.isInitialized ? "✅ Ready" : "❌ Not Ready")
                    .font(.caption.monospaced())
            }
            
            if let locationService = dependencies.locationService {
                HStack {
                    Text("Auth Status:")
                    Text(authStatusText(locationService.authorizationStatus))
                        .font(.caption.monospaced())
                        .foregroundColor(authStatusColor(locationService.authorizationStatus))
                }
                
                HStack {
                    Text("Location:")
                    Text(locationService.currentLocation != nil ? "✅ Available" : "❌ Not Available")
                        .font(.caption.monospaced())
                        .foregroundColor(locationService.currentLocation != nil ? .green : .red)
                }
                
                HStack {
                    Text("Updating:")
                    Text(locationService.isLocationUpdating ? "✅ Yes" : "❌ No")
                        .font(.caption.monospaced())
                        .foregroundColor(locationService.isLocationUpdating ? .green : .red)
                }
                
                HStack {
                    Text("GPS Signal:")
                    Text(locationService.isGPSSignalStrong ? "✅ Strong" : "❌ Weak")
                        .font(.caption.monospaced())
                        .foregroundColor(locationService.isGPSSignalStrong ? .green : .orange)
                }
                
                if let location = locationService.currentLocation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coordinates:")
                            .font(.caption.bold())
                        Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                            .font(.caption.monospaced())
                        Text("Lng: \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption.monospaced())
                        Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m")
                            .font(.caption.monospaced())
                        Text("Age: \(Int(-location.timestamp.timeIntervalSinceNow))s")
                            .font(.caption.monospaced())
                    }
                }
                
                if let error = locationService.locationError {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Error:")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack {
                    Button("Request Permission") {
                        locationService.requestLocationPermission()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Start Updates") {
                        locationService.startLocationUpdates()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Stop Updates") {
                        locationService.stopLocationUpdates()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
            }
        }
        .font(.caption)
        .padding(8)
    }
    
    private func checkLocationNow() {
        guard let locationService = dependencies.locationService else { return }
        
        print("🔍 Debug Panel: Manual refresh triggered")
        print("🔍 Debug Panel: Auth status: \(locationService.authorizationStatus)")
        print("🔍 Debug Panel: Is updating: \(locationService.isLocationUpdating)")
        print("🔍 Debug Panel: Current location: \(String(describing: locationService.currentLocation))")
        print("🔍 Debug Panel: Error: \(String(describing: locationService.locationError))")
        
        if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
            if !locationService.isLocationUpdating {
                print("🔍 Debug Panel: Starting location updates")
                locationService.startLocationUpdates()
            }
        }
    }
    
    private func authStatusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func authStatusColor(_ status: CLAuthorizationStatus) -> Color {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Navigation Destinations

enum NavigationDestination: Hashable {
    case settings
    case onboarding
}

// MARK: - Main Map View

struct MainMapView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    
    var body: some View {
        MapView()
            .environmentObject(dependencies.locationService)
            .environmentObject(dependencies.searchViewModel)
            .environmentObject(dependencies.navigationEngine)
            .environmentObject(dependencies.navigationViewModel)
            .environmentObject(dependencies.userPreferences)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 16) {
                Image(systemName: "location.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Haptic Navigation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Navigate with touch")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Features
            VStack(spacing: 24) {
                OnboardingFeature(
                    icon: "hand.wave.fill",
                    title: "Haptic Feedback",
                    description: "Feel your way with carefully designed haptic patterns for each turn"
                )
                
                OnboardingFeature(
                    icon: "location.circle.fill",
                    title: "Location Services",
                    description: "We need your location to provide turn-by-turn navigation"
                )
                
                OnboardingFeature(
                    icon: "moon.fill",
                    title: "Pocket Navigation",
                    description: "Navigate without looking at your phone using haptic mode"
                )
            }
            
            Spacer()
            
            // Permission Button
            VStack(spacing: 16) {
                Button(action: requestLocationPermission) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Enable Location Services")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button("Continue without location") {
                    completeOnboarding()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarHidden(true)
    }
    
    private func requestLocationPermission() {
        dependencies.locationService?.requestLocationPermission()
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        // Note: Since OnboardingView is shown conditionally in ContentView, 
        // the state change will be handled by ContentView's property observers
    }
}

// MARK: - Onboarding Feature

struct OnboardingFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(DependencyContainer.shared)
}