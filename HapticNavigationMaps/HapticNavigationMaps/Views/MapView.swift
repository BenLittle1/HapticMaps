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
    
    // MARK: - Tap-to-Navigate State
    @State private var tappedLocation: TappedLocation?
    @State private var showingTappedLocationOptions = false
    
    var body: some View {
        ZStack {
            // Map View with MapReader for coordinate conversion
            MapReader { mapProxy in
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
                    
                    // Tapped location annotation
                    if let tapped = tappedLocation {
                        Annotation("Tapped Location", coordinate: tapped.coordinate) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 30))
                                .background(Circle().fill(.white).frame(width: 32, height: 32))
                        }
                        .annotationTitles(.hidden)
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
                .onTapGesture { tapLocation in
                    handleMapTap(at: tapLocation, mapProxy: mapProxy)
                }
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
            
            // Tapped Location Options
            if showingTappedLocationOptions, let tapped = tappedLocation {
                VStack {
                    Spacer()
                    
                    TappedLocationPanel(
                        tappedLocation: tapped,
                        onGetDirections: {
                            Task {
                                await calculateRouteToDestination(tapped.mapItem)
                                showingTappedLocationOptions = false
                            }
                        },
                        onDismiss: {
                            showingTappedLocationOptions = false
                            tappedLocation = nil
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showingTappedLocationOptions)
            }
            
            // Route Calculation Loading State
            if case .calculating = navigationEngine.navigationState {
                VStack {
                    Spacer()
                    
                    RouteCalculationView(
                        onCancel: {
                            navigationEngine.cancelRouteCalculation()
                        },
                        onTimeout: {
                            navigationEngine.cancelRouteCalculation()
                            // Show error message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                handleRouteCalculationError(NavigationError.routeCalculationTimeout)
                            }
                        }
                    )
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
        // Validate location coordinate
        guard !location.coordinate.latitude.isNaN && !location.coordinate.longitude.isNaN &&
              location.coordinate.latitude >= -90 && location.coordinate.latitude <= 90 &&
              location.coordinate.longitude >= -180 && location.coordinate.longitude <= 180 else {
            print("Invalid location coordinate: \(location.coordinate)")
            return
        }
        
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
        
        // Validate location coordinate
        guard !location.coordinate.latitude.isNaN && !location.coordinate.longitude.isNaN &&
              location.coordinate.latitude >= -90 && location.coordinate.latitude <= 90 &&
              location.coordinate.longitude >= -180 && location.coordinate.longitude <= 180 else {
            print("Invalid location coordinate for search region: \(location.coordinate)")
            return
        }
        
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
            // Validate coordinate before using it
            guard !result.coordinate.latitude.isNaN && !result.coordinate.longitude.isNaN &&
                  result.coordinate.latitude >= -90 && result.coordinate.latitude <= 90 &&
                  result.coordinate.longitude >= -180 && result.coordinate.longitude <= 180 else {
                print("Invalid search result coordinate: \(result.coordinate)")
                return
            }
            
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
        
        // Validate coordinate before using it
        guard !result.coordinate.latitude.isNaN && !result.coordinate.longitude.isNaN &&
              result.coordinate.latitude >= -90 && result.coordinate.latitude <= 90 &&
              result.coordinate.longitude >= -180 && result.coordinate.longitude <= 180 else {
            print("Invalid search result coordinate: \(result.coordinate)")
            return
        }
        
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
        guard !rect.isNull && !rect.isEmpty else {
            print("Invalid map rect for route")
            return
        }
        
        let region = MKCoordinateRegion(rect)
        
        // Validate the resulting region
        guard !region.center.latitude.isNaN && !region.center.longitude.isNaN &&
              region.center.latitude >= -90 && region.center.latitude <= 90 &&
              region.center.longitude >= -180 && region.center.longitude <= 180 &&
              region.span.latitudeDelta > 0 && region.span.longitudeDelta > 0 else {
            print("Invalid region calculated from route rect")
            return
        }
        
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
    
    private func handleMapTap(at location: CGPoint, mapProxy: MapProxy) {
        // Dismiss search when tapping on map
        if searchViewModel.isSearching {
            searchViewModel.cancelSearch()
            return
        }
        
        // Convert screen coordinates to map coordinates
        guard let coordinate = mapProxy.convert(location, from: .local) else {
            print("Failed to convert tap location to coordinate")
            return
        }
        
        // Validate coordinate
        guard !coordinate.latitude.isNaN && !coordinate.longitude.isNaN &&
              coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
              coordinate.longitude >= -180 && coordinate.longitude <= 180 else {
            print("Invalid tapped coordinate: \(coordinate)")
            return
        }
        
        // Check if we're tapping near an existing annotation (within ~50 meters)
        let tapThreshold: CLLocationDistance = 50 // meters
        
        // Check search result annotations
        for result in searchViewModel.searchResults {
            let annotationLocation = CLLocation(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude)
            let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            if annotationLocation.distance(from: tapLocation) < tapThreshold {
                handleResultSelection(result)
                return
            }
        }
        
        // Check if tapping near current tapped location
        if let tapped = tappedLocation {
            let existingLocation = CLLocation(latitude: tapped.coordinate.latitude, longitude: tapped.coordinate.longitude)
            let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            if existingLocation.distance(from: tapLocation) < tapThreshold {
                showingTappedLocationOptions = true
                return
            }
        }
        
        // Create new tapped location
        tappedLocation = TappedLocation(coordinate: coordinate)
        
        // Clear any selected search result annotation
        selectedAnnotation = nil
        
        // Show options for the tapped location
        showingTappedLocationOptions = true
        
        print("📍 Map tapped at: \(coordinate.latitude), \(coordinate.longitude)")
    }
}

// MARK: - Route Calculation View

struct RouteCalculationView: View {
    let onCancel: () -> Void
    let onTimeout: () -> Void
    
    @State private var timeRemaining: Double = 15.0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // Progress indicator with countdown
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(1.0 - (timeRemaining / 15.0)))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: timeRemaining)
                    
                    Text("\(Int(timeRemaining))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calculating Route...")
                        .font(.headline)
                    Text("Finding the best path for you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    stopTimer()
                    onCancel()
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timeRemaining = 15.0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            
            if timeRemaining <= 0 {
                stopTimer()
                onTimeout()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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