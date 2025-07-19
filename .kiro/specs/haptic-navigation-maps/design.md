# Design Document

## Overview

The Haptic Navigation Maps application is an iOS app built using SwiftUI that provides traditional mapping functionality enhanced with innovative haptic feedback navigation. The app allows users to navigate without looking at their screen through carefully designed haptic patterns, making it ideal for walking or cycling navigation.

The application follows a design-first approach using Figma components that are translated into SwiftUI views, ensuring consistent visual design and user experience. The core architecture leverages MapKit for mapping functionality and CoreHaptics for the unique haptic navigation features.

## Architecture

### High-Level Architecture

The application follows the MVVM (Model-View-ViewModel) pattern with SwiftUI, organized into the following layers:

```
┌─────────────────────────────────────────┐
│                Views                    │
│  (SwiftUI Views from Figma Components)  │
├─────────────────────────────────────────┤
│              ViewModels                 │
│    (Business Logic & State Management)  │
├─────────────────────────────────────────┤
│               Services                  │
│  (Location, Navigation, Haptic, Search) │
├─────────────────────────────────────────┤
│               Models                    │
│     (Data Structures & Entities)        │
├─────────────────────────────────────────┤
│            System Frameworks            │
│   (MapKit, CoreHaptics, CoreLocation)   │
└─────────────────────────────────────────┘
```

### Core Components

1. **MapView**: SwiftUI wrapper around MapKit for map display and interaction
2. **NavigationEngine**: Manages route calculation, turn-by-turn instructions, and progress tracking
3. **HapticNavigationService**: Handles haptic pattern generation and playback
4. **LocationService**: Manages location permissions and real-time location updates
5. **SearchService**: Handles location search using MKLocalSearch
6. **DesignSystem**: Figma-derived components and styling#
# Components and Interfaces

### 1. Location Service

**Purpose**: Manages location permissions, tracking, and updates

**Interface**:
```swift
protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    
    func requestLocationPermission()
    func startLocationUpdates()
    func stopLocationUpdates()
}
```

**Key Responsibilities**:
- Request and manage location permissions (when-in-use and always)
- Provide real-time location updates
- Handle permission state changes
- Background location tracking during navigation

### 2. Search Service

**Purpose**: Handles location search and geocoding

**Interface**:
```swift
protocol SearchServiceProtocol {
    func searchLocations(query: String) async throws -> [MKMapItem]
    func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark]
}
```

**Key Responsibilities**:
- Execute MKLocalSearch queries
- Return formatted search results
- Handle search errors and edge cases
- Provide location details and metadata

### 3. Navigation Engine

**Purpose**: Core navigation logic, route calculation, and progress tracking

**Interface**:
```swift
protocol NavigationEngineProtocol {
    var currentRoute: MKRoute? { get }
    var currentStep: MKRouteStep? { get }
    var navigationState: NavigationState { get }
    
    func calculateRoute(to destination: MKMapItem) async throws -> MKRoute
    func startNavigation(route: MKRoute)
    func updateProgress(location: CLLocation)
    func stopNavigation()
}
```

**Key Responsibilities**:
- Calculate routes using MKDirections
- Track navigation progress
- Determine current navigation step
- Provide turn-by-turn instructions
- Calculate distance to next maneuver#
## 4. Haptic Navigation Service

**Purpose**: Manages haptic feedback patterns for navigation cues

**Interface**:
```swift
protocol HapticNavigationServiceProtocol {
    var isHapticModeEnabled: Bool { get set }
    
    func initializeHapticEngine() throws
    func playTurnLeftPattern()
    func playTurnRightPattern()
    func playContinueStraightPattern()
    func playArrivalPattern()
    func stopAllHaptics()
}
```

**Key Responsibilities**:
- Initialize and manage CHHapticEngine
- Define custom haptic patterns for each navigation cue
- Handle haptic engine state and errors
- Provide fallback for devices without haptic support

### 5. Design System Components

**Purpose**: Figma-derived SwiftUI components for consistent UI

**Components**:
- `MapButton`: Styled buttons for map interactions
- `SearchBar`: Custom search input component
- `NavigationCard`: Turn-by-turn instruction display
- `RouteInfoPanel`: Route summary with time and distance
- `HapticModeToggle`: Switch between visual and haptic modes

## Data Models

### NavigationState
```swift
enum NavigationState {
    case idle
    case calculating
    case navigating(mode: NavigationMode)
    case arrived
}

enum NavigationMode {
    case visual
    case haptic
}
```

### RouteStep
```swift
struct RouteStep {
    let instruction: String
    let distance: CLLocationDistance
    let maneuverType: MKDirectionsTransportType
    let coordinate: CLLocationCoordinate2D
}
```

### HapticPattern
```swift
struct HapticPattern {
    let events: [CHHapticEvent]
    let duration: TimeInterval
    let intensity: Float
}
```

### SearchResult
```swift
struct SearchResult {
    let mapItem: MKMapItem
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}
```## Er
ror Handling

### Location Errors
- **Permission Denied**: Show alert with settings redirect
- **Location Unavailable**: Fallback to manual location entry
- **Background Permission Lost**: Notify user and request re-authorization

### Navigation Errors
- **No Route Found**: Display alternative suggestions or manual route entry
- **Route Calculation Failed**: Retry with different parameters or show error message
- **GPS Signal Lost**: Continue with last known position and notify user

### Haptic Errors
- **Haptic Engine Unavailable**: Graceful fallback to audio or visual cues
- **Pattern Playback Failed**: Log error and continue navigation
- **Device Compatibility**: Detect haptic capabilities and adjust features

### Search Errors
- **Network Unavailable**: Show cached results or offline message
- **No Results Found**: Suggest alternative search terms
- **Search Service Error**: Retry mechanism with exponential backoff

## Testing Strategy

### Unit Testing
- **Location Service**: Mock CLLocationManager for permission and location scenarios
- **Navigation Engine**: Test route calculation with mock MKDirections responses
- **Haptic Service**: Verify pattern creation and engine state management
- **Search Service**: Mock MKLocalSearch for various query scenarios

### Integration Testing
- **End-to-End Navigation Flow**: Test complete navigation from search to arrival
- **Permission Flows**: Test various location permission scenarios
- **Background Behavior**: Verify haptic feedback continues when app is backgrounded
- **Mode Switching**: Test transitions between visual and haptic navigation modes

### UI Testing
- **Figma Component Fidelity**: Verify SwiftUI components match Figma designs
- **Navigation Interface**: Test turn-by-turn instruction display and updates
- **Search Interface**: Verify search results display and selection
- **Accessibility**: Test VoiceOver and other accessibility features

### Device Testing
- **Haptic Capability Detection**: Test on devices with and without haptic engines
- **Performance**: Test on various iOS device generations
- **Battery Impact**: Monitor location and haptic service battery usage
- **Background Modes**: Verify background location and haptic functionality

### Haptic Pattern Testing
- **Pattern Distinctiveness**: Ensure users can differentiate between turn patterns
- **Timing Accuracy**: Verify haptic cues trigger at appropriate distances
- **Pattern Intensity**: Test haptic strength across different devices
- **User Feedback**: Conduct user testing for haptic pattern effectiveness