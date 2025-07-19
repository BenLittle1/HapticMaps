import SwiftUI

@main
struct HapticNavigationMapsApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appCoordinator.isLoading {
                    // Show loading screen during app initialization
                    AppLoadingView()
                } else if appCoordinator.initializationError != nil {
                    // Show error screen if initialization failed
                    AppErrorView(
                        errorMessage: appCoordinator.initializationErrorMessage,
                        onRetry: {
                            Task {
                                await appCoordinator.retryInitialization()
                            }
                        }
                    )
                } else if appCoordinator.isInitialized {
                    // Show main app content when initialized
                    ContentView()
                        .environmentObject(appCoordinator)
                        .environmentObject(appCoordinator.dependencies)
                } else {
                    // Fallback to loading view
                    AppLoadingView()
                }
            }
            .task {
                // Initialize app when first launched
                await appCoordinator.initializeApp()
            }
        }
    }
}

// MARK: - Loading View

struct AppLoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "location.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Haptic Navigation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Initializing...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 16)
            }
        }
    }
}

// MARK: - Error View

struct AppErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Initialization Error")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.top, 16)
            }
        }
    }
}