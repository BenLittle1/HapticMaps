import SwiftUI
import MapKit
import CoreLocation
import CoreHaptics

struct MapView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationEngine: NavigationEngine
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var userPreferences: UserPreferences
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingLocationAlert = false
    @State private var selectedAnnotation: SearchResult?
    @State private var showingRouteInfo = false
    @State private var showingRouteSelection = false
    @State private var selectedRouteIndex = 0
    @State private var showingRouteError = false
    @State private var routeErrorMessage = ""
    @State private var showingModeSettings = false
    
    var body: some View {
        ZStack {
            // Map View
            Map(position: $cameraPosition) {
                // Current location annotation
                if let location = locationService.currentLocation {
                    Annotation("Current Location", coordinate: location.coordinate) {
                        Circle()
                            .fill(.blue)
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 20, height: 20)
                    }
                }
                
                // Search result annotations
                ForEach(searchViewModel.searchResults) { result in
                    Annotation(result.title, coordinate: result.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 30))
                            .background(Circle().fill(.white).frame(width: 32, height: 32))
                    }
                    .annotationTitles(.hidden)
                }
                
                // Selected annotation (highlighted)
                if let selected = selectedAnnotation {
                    Annotation(selected.title, coordinate: selected.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 35))
                            .background(Circle().fill(.white).frame(width: 38, height: 38))
                    }
                }
                
                // Route polylines
                ForEach(Array(navigationEngine.availableRoutes.enumerated()), id: \.offset) { index, route in
                    MapPolyline(route.polyline)
                        .stroke(
                            index == selectedRouteIndex ? .blue : .gray,
                            style: StrokeStyle(
                                lineWidth: index == selectedRouteIndex ? 6 : 4,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                setupLocationTracking()
            }
            .onChange(of: locationService.currentLocation) { _, newLocation in
                if let location = newLocation {
                    updateCameraPosition(for: location)
                    updateSearchRegion()
                }
            }
            .onChange(of: locationService.authorizationStatus) { _, status in
                handleLocationAuthorizationChange(status)
            }
            .onChange(of: searchViewModel.selectedResult) { _, selectedResult in
                handleSearchResultSelection(selectedResult)
            }
            .onTapGesture {
                // Dismiss search when tapping on map
                if searchViewModel.isSearching {
                    searchViewModel.cancelSearch()
                }
            }
            .onChange(of: locationService.currentLocation) { _, newLocation in
                // Update navigation engine with current location
                if let location = newLocation {
                    navigationEngine.updateProgress(location: location)
                    navigationViewModel.updateProgress(location: location)
                }
            }
            
            // Search Interface Overlay
            VStack {
                // Search Bar
                SearchBar(
                    text: $searchViewModel.searchText,
                    isSearching: $searchViewModel.isSearching,
                    onSearchButtonClicked: {
                        searchViewModel.performSearch()
                    },
                    onCancelButtonClicked: {
                        searchViewModel.cancelSearch()
                    }
                )
                .padding(.top, 8)
                
                // Search Results
                if searchViewModel.shouldShowResults {
                    SearchResultsView(
                        searchViewModel: searchViewModel,
                        userLocation: locationService.currentLocation,
                        onResultSelected: { result in
                            handleResultSelection(result)
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Current Mode Indicator (when not navigating)
                if case .idle = navigationEngine.navigationState {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                showingModeSettings = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: userPreferences.preferredNavigationMode.iconName)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Default Mode")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Text(userPreferences.preferredNavigationMode.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(userPreferences.preferredNavigationMode == .haptic ? .purple : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(radius: 2)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Location permission overlay
            if shouldShowLocationPrompt {
                LocationPermissionOverlay(
                    authorizationStatus: locationService.authorizationStatus,
                    onRequestPermission: {
                        locationService.requestLocationPermission()
                    },
                    onOpenSettings: {
                        openLocationSettings()
                    }
                )
            }
            
            // Route Selection Panel
            if showingRouteSelection && navigationEngine.availableRoutes.count > 1 {
                VStack {
                    Spacer()
                    
                    RouteSelectionPanel(
                        routes: navigationEngine.availableRoutes,
                        selectedRouteIndex: $selectedRouteIndex,
                        onRouteSelected: { route in
                            navigationEngine.selectRoute(route)
                            selectedRouteIndex = navigationEngine.availableRoutes.firstIndex(where: { $0 === route }) ?? 0
                            showingRouteSelection = false
                            showingRouteInfo = true
                        },
                        onDismiss: {
                            showingRouteSelection = false
                            navigationEngine.clearRoutes()
                        }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showingRouteSelection)
            }
            
            // Route Info Panel
            if showingRouteInfo, let route = navigationEngine.currentRoute {
                VStack {
                    Spacer()
                    
                    RouteInfoPanel(
                        route: route,
                                        onStartNavigation: {
                            // Start navigation with user's preferred mode
                            let startMode = userPreferences.preferredNavigationMode
                            navigationEngine.startNavigation(route: route, mode: startMode)
                            showingRouteInfo = false
                            saveCurrentNavigationState()
                        },
                        onDismiss: {
                            showingRouteInfo = false
                            navigationEngine.clearRoutes()
                        }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showingRouteInfo)
            }
            
            // Route Calculation Loading State
            if case .calculating = navigationEngine.navigationState {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        HStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Calculating...")
                                    .font(.headline)
                                Text("Preparing navigation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Stop") {
                                navigationEngine.cancelRouteCalculation()
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: navigationEngine.navigationState)
            }
            
            // Navigation Interface - Adaptive based on mode
            if case .navigating(let mode) = navigationEngine.navigationState {
                if mode == .haptic {
                    // Full-screen haptic navigation interface
                    HapticNavigationView(
                        currentStep: navigationViewModel.currentStep,
                        nextStep: navigationViewModel.nextStep,
                        distanceToNextManeuver: navigationViewModel.distanceToNextManeuver,
                        navigationState: navigationEngine.navigationState,
                        routeProgress: navigationViewModel.routeProgress,
                        isHapticCapable: isHapticCapable,
                        onStopNavigation: {
                            navigationViewModel.stopNavigation()
                            userPreferences.clearNavigationState()
                        },
                        onToggleMode: {
                            navigationViewModel.toggleNavigationMode()
                            saveCurrentNavigationState()
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1) // Ensure it appears above the map
                } else {
                    // Standard visual navigation card
                    VStack {
                        Spacer()
                        
                        NavigationCard(
                            currentStep: navigationViewModel.currentStep,
                            nextStep: navigationViewModel.nextStep,
                            distanceToNextManeuver: navigationViewModel.distanceToNextManeuver,
                            navigationState: navigationEngine.navigationState,
                            onStopNavigation: {
                                navigationViewModel.stopNavigation()
                                userPreferences.clearNavigationState()
                            },
                            onToggleMode: {
                                navigationViewModel.toggleNavigationMode()
                                saveCurrentNavigationState()
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Arrival Confirmation
            if case .arrived = navigationEngine.navigationState {
                VStack {
                    Spacer()
                    
                    NavigationCard(
                        currentStep: nil,
                        nextStep: nil,
                        distanceToNextManeuver: 0,
                        navigationState: navigationEngine.navigationState,
                        onStopNavigation: {
                            navigationViewModel.stopNavigation()
                        },
                        onToggleMode: {
                            // No mode toggle when arrived
                        }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Location Access Required", isPresented: $showingLocationAlert) {
            Button("Settings") {
                openLocationSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings to see your current location on the map.")
        }
        .alert("Route Calculation Error", isPresented: $showingRouteError) {
            Button("OK", role: .cancel) {
                navigationEngine.clearError()
            }
            Button("Retry") {
                if let selectedResult = selectedAnnotation {
                    Task {
                        await calculateRouteToDestination(selectedResult.mapItem)
                    }
                }
            }
        } message: {
            Text(routeErrorMessage)
        }
        .animation(.easeInOut(duration: 0.3), value: navigationEngine.navigationState)
        .onChange(of: navigationEngine.navigationState) { _, newState in
            handleNavigationStateChange(newState)
        }
        .sheet(isPresented: $showingModeSettings) {
            NavigationModeSettingsView()
        }
    }
    
    private var shouldShowLocationPrompt: Bool {
        switch locationService.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            return true
        default:
            return false
        }
    }
    
    private func setupLocationTracking() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            locationService.startLocationUpdates()
        default:
            break
        }
    }
    
    private func updateCameraPosition(for location: CLLocation) {
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
            )
        }
    }
    
    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationService.startLocationUpdates()
        case .denied, .restricted:
            showingLocationAlert = true
        default:
            break
        }
    }
    
    private func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func updateSearchRegion() {
        guard let location = locationService.currentLocation else { return }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 10000, // 10km radius for search
            longitudinalMeters: 10000
        )
        
        searchViewModel.performSearch(in: region)
    }
    
    private func handleSearchResultSelection(_ selectedResult: SearchResult?) {
        selectedAnnotation = selectedResult
        
        if let result = selectedResult {
            // Animate to the selected location
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: result.coordinate,
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    )
                )
            }
        }
    }
    
    private func handleResultSelection(_ result: SearchResult) {
        selectedAnnotation = result
        
        // Animate to the selected location
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: result.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
            )
        }
        
        // Calculate route to selected destination
        Task {
            await calculateRouteToDestination(result.mapItem)
        }
    }
    
    private func calculateRouteToDestination(_ destination: MKMapItem) async {
        do {
            let _ = try await navigationEngine.calculateRoute(to: destination)
            
            // Show appropriate UI based on number of routes
            await MainActor.run {
                if navigationEngine.availableRoutes.count > 1 {
                    showingRouteSelection = true
                } else if navigationEngine.availableRoutes.count == 1 {
                    showingRouteInfo = true
                }
                
                // Fit the route in the camera view
                if let route = navigationEngine.currentRoute {
                    fitRouteInView(route)
                }
            }
        } catch {
            // Handle route calculation error
            await MainActor.run {
                handleRouteCalculationError(error)
            }
        }
    }
    
    private func fitRouteInView(_ route: MKRoute) {
        let rect = route.polyline.boundingMapRect
        let region = MKCoordinateRegion(rect)
        
        // Add some padding around the route
        let paddedRegion = MKCoordinateRegion(
            center: region.center,
            latitudinalMeters: region.span.latitudeDelta * 111000 * 1.2, // Convert degrees to meters with padding
            longitudinalMeters: region.span.longitudeDelta * 111000 * 1.2
        )
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(paddedRegion)
        }
    }
    
    private func handleRouteCalculationError(_ error: Error) {
        if let navError = error as? NavigationError {
            routeErrorMessage = navError.localizedDescription
        } else {
            routeErrorMessage = error.localizedDescription
        }
        showingRouteError = true
    }
    
    // MARK: - Computed Properties
    
    private var isHapticCapable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    private var currentNavigationMode: NavigationMode {
        if case .navigating(let mode) = navigationEngine.navigationState {
            return mode
        }
        return userPreferences.preferredNavigationMode
    }
    
    // MARK: - Helper Methods
    
    private func saveCurrentNavigationState() {
        guard let route = navigationEngine.currentRoute else { return }
        
        // Create route state for persistence
        let routeState = NavigationRouteState(
            from: route,
            currentStepIndex: navigationViewModel.currentStepIndex,
            destinationName: selectedAnnotation?.title ?? "Destination"
        )
        
        // Save current state
        userPreferences.saveNavigationState(
            route: routeState,
            mode: currentNavigationMode,
            progress: navigationViewModel.routeProgress
        )
    }
    
    private func handleNavigationStateChange(_ newState: NavigationState) {
        switch newState {
        case .navigating(let mode):
            // Update user preferences with current mode
            userPreferences.preferredNavigationMode = mode
            saveCurrentNavigationState()
            
            // Configure screen behavior for haptic mode
            if mode == .haptic && userPreferences.keepScreenAwakeInHapticMode {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            
        case .idle, .arrived:
            // Re-enable idle timer when navigation stops
            UIApplication.shared.isIdleTimerDisabled = false
            
            // Clear navigation state when stopped
            if case .idle = newState {
                userPreferences.clearNavigationState()
            }
            
        case .calculating:
            break
        }
    }
}

struct LocationPermissionOverlay: View {
    let authorizationStatus: CLAuthorizationStatus
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(overlayTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(overlayMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: buttonAction) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .padding(.horizontal, 32)
    }
    
    private var overlayTitle: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location Access Needed"
        case .denied, .restricted:
            return "Location Access Denied"
        default:
            return "Location Unavailable"
        }
    }
    
    private var overlayMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "To show your current location on the map, please allow location access."
        case .denied, .restricted:
            return "Location access is required to display your current position. Please enable it in Settings."
        default:
            return "Unable to access your location at this time."
        }
    }
    
    private var buttonTitle: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Allow Location Access"
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Retry"
        }
    }
    
    private var buttonAction: () -> Void {
        switch authorizationStatus {
        case .notDetermined:
            return onRequestPermission
        case .denied, .restricted:
            return onOpenSettings
        default:
            return onRequestPermission
        }
    }
}

#Preview {
    MapView()
}