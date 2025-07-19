import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var showingOnboarding = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if appCoordinator.shouldShowOnboarding && !hasUserSeenOnboarding {
                    OnboardingView()
                } else {
                    MainMapView()
                }
            }
            .navigationTitle("Haptic Navigation")
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .onChange(of: dependencies.locationService?.authorizationStatus) { _, status in
            handleLocationAuthorizationChange(status)
        }
    }
    
    // MARK: - Private Properties
    
    private var hasUserSeenOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }
    
    // MARK: - Private Methods
    
    private func checkOnboardingStatus() {
        if appCoordinator.shouldShowOnboarding && !hasUserSeenOnboarding {
            showingOnboarding = true
        }
    }
    
    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus?) {
        guard let status = status else { return }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // User granted permission, dismiss onboarding if showing
            if showingOnboarding {
                completeOnboarding()
            }
        case .denied, .restricted:
            // Permission denied, show onboarding/settings
            if !hasUserSeenOnboarding {
                showingOnboarding = true
            }
        default:
            break
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        showingOnboarding = false
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
    @Environment(\.dismiss) var dismiss
    
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
        dismiss()
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