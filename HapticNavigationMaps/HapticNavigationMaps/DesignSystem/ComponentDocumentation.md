# Design System Components Documentation

This document provides comprehensive documentation for the Haptic Navigation Maps design system components, based on Figma specifications and implemented in SwiftUI.

## Table of Contents

1. [Design Tokens](#design-tokens)
2. [MapButton](#mapbutton)
3. [RouteInfoPanel](#routeinfopanel)
4. [NavigationCard](#navigationcard)
5. [HapticModeToggle](#hapticmodetoggle)
6. [SearchBar](#searchbar)
7. [SearchResultRow](#searchresultrow)
8. [RouteSelectionPanel](#routeselectionpanel)
9. [Usage Guidelines](#usage-guidelines)
10. [Accessibility](#accessibility)

---

## Design Tokens

The `DesignTokens` struct provides centralized design constants for consistent styling across the application.

### Colors

```swift
// Primary Colors
DesignTokens.Colors.primary          // Blue - primary actions
DesignTokens.Colors.primaryLight     // Light blue - backgrounds
DesignTokens.Colors.secondary        // Purple - secondary actions

// System Colors
DesignTokens.Colors.success          // Green - success states
DesignTokens.Colors.warning          // Orange - warning states
DesignTokens.Colors.error            // Red - error states

// Navigation Colors
DesignTokens.Colors.navigationTurnLeft    // Orange for left turns
DesignTokens.Colors.navigationTurnRight   // Orange for right turns
DesignTokens.Colors.navigationStraight    // Blue for straight ahead
DesignTokens.Colors.navigationArrival     // Green for arrival
```

### Typography

```swift
// Display Typography
DesignTokens.Typography.largeTitle   // Large title text
DesignTokens.Typography.title1       // Main titles
DesignTokens.Typography.title2       // Section titles
DesignTokens.Typography.headline     // Headlines

// Body Typography
DesignTokens.Typography.body         // Regular body text
DesignTokens.Typography.bodyEmphasis // Emphasized body text
DesignTokens.Typography.subheadline  // Subheadings
DesignTokens.Typography.caption1     // Captions
```

### Spacing

```swift
DesignTokens.Spacing.xs     // 4pt  - Very tight spacing
DesignTokens.Spacing.sm     // 8pt  - Tight spacing
DesignTokens.Spacing.md     // 12pt - Default spacing
DesignTokens.Spacing.lg     // 16pt - Loose spacing
DesignTokens.Spacing.xl     // 20pt - Very loose spacing
DesignTokens.Spacing.xxl    // 24pt - Extra loose spacing
```

### View Extensions

```swift
// Apply consistent card styling
.cardStyle()

// Apply panel styling with rounded top corners
.panelStyle()

// Add a handle bar for panels
.handleBar()
```

---

## MapButton

A versatile button component for map interactions with consistent styling and multiple variants.

### Basic Usage

```swift
MapButton.primary(
    action: { print("Button tapped") },
    icon: "location.fill",
    label: "My Location"
)
```

### Button Styles

#### Primary Button
```swift
MapButton.primary(
    action: { /* action */ },
    icon: "location.fill",
    label: "Start Navigation",
    size: .large
)
```

#### Secondary Button
```swift
MapButton.secondary(
    action: { /* action */ },
    icon: "map",
    label: "Map Type"
)
```

#### Map Overlay Button (Compact)
```swift
MapButton.mapOverlay(
    action: { /* action */ },
    icon: "plus"
)
```

#### Floating Action Button
```swift
MapButton.floating(
    action: { /* action */ },
    icon: "location.fill",
    size: .large
)
```

#### Destructive Button
```swift
MapButton.destructive(
    action: { /* action */ },
    icon: "stop.fill",
    label: "Stop Navigation"
)
```

### Button Sizes

- `.small` - Compact buttons for tight spaces
- `.medium` - Default size for most use cases
- `.large` - Prominent actions and CTAs
- `.compact` - Minimal buttons for overlays

### States

- **Enabled** - Default interactive state
- **Disabled** - Non-interactive with reduced opacity
- **Pressed** - Visual feedback during interaction

---

## RouteInfoPanel

A panel component for displaying route information including time and distance estimates.

### Usage

```swift
RouteInfoPanel(
    route: calculatedRoute,
    onStartNavigation: {
        // Start navigation action
    },
    onDismiss: {
        // Dismiss panel action
    }
)
```

### Features

- **Route Metrics**: Displays travel time and distance with icons
- **Handle Bar**: Allows panel dragging interaction
- **Start Navigation CTA**: Primary action button
- **Dismiss Action**: Close button in top-right corner

### Layout Structure

```
┌─────────────────────────────────┐
│           Handle Bar            │
├─────────────────────────────────┤
│ Route Information    [X]        │
│ Walking directions              │
├─────────────────────────────────┤
│ [🕐] 15 min    [📍] 1.2 km     │
│ Travel time    Distance         │
├─────────────────────────────────┤
│    [📍] Start Navigation        │
└─────────────────────────────────┘
```

---

## NavigationCard

A card component for displaying turn-by-turn navigation instructions during active navigation.

### Usage

```swift
NavigationCard(
    currentStep: routeStep,
    nextStep: nextRouteStep,
    distanceToNextManeuver: 150.0,
    navigationState: .navigating(mode: .visual),
    onStopNavigation: { /* stop action */ },
    onToggleMode: { /* toggle mode action */ }
)
```

### Features

- **Current Instruction**: Large display of current navigation step
- **Next Instruction Preview**: Upcoming navigation step
- **Distance Display**: Distance to next maneuver
- **Mode Toggle**: Switch between visual and haptic modes
- **Stop Navigation**: End navigation session

### Navigation States

- `.idle` - No active navigation
- `.calculating` - Route calculation in progress
- `.navigating(mode)` - Active navigation with specified mode
- `.arrived` - Destination reached

---

## HapticModeToggle

A toggle component for switching between visual and haptic navigation modes.

### Usage

```swift
HapticModeToggle(
    currentMode: $navigationMode,
    isHapticCapable: $hapticCapability,
    onModeChanged: { newMode in
        // Handle mode change
    }
)
```

### Compact Version

```swift
CompactHapticModeToggle(
    currentMode: $navigationMode,
    isHapticCapable: hapticCapability,
    onModeChanged: { newMode in
        // Handle mode change
    }
)
```

### Features

- **Mode Selection**: Segmented picker for visual/haptic modes
- **Capability Detection**: Automatically detects haptic support
- **Warning Display**: Shows warning when haptic unavailable
- **Mode Description**: Explains each navigation mode

---

## SearchBar

A custom search input component with integrated search and clear functionality.

### Usage

```swift
SearchBar(
    text: $searchText,
    isSearching: $isSearchActive,
    placeholder: "Search for places...",
    onSearchButtonClicked: {
        // Perform search
    },
    onCancelButtonClicked: {
        // Cancel search
    }
)
```

### Features

- **Search Icon**: Leading magnifying glass icon
- **Clear Button**: Trailing X button when text is present
- **Cancel Button**: Appears during active search
- **Smooth Animations**: Animated transitions between states

---

## SearchResultRow

A row component for displaying individual search results in a list.

### Usage

```swift
SearchResultRow(
    searchResult: result,
    userLocation: currentLocation,
    onTap: {
        // Handle result selection
    }
)
```

### Features

- **Location Icon**: Consistent pin icon for all results
- **Title & Subtitle**: Primary and secondary text
- **Distance Display**: Shows distance from user location
- **Chevron Indicator**: Right arrow for navigation

---

## RouteSelectionPanel

A panel component for selecting between multiple calculated route options.

### Usage

```swift
RouteSelectionPanel(
    routes: availableRoutes,
    selectedRouteIndex: $selectedIndex,
    onRouteSelected: { route in
        // Handle route selection
    },
    onDismiss: {
        // Dismiss panel
    }
)
```

### Features

- **Route Options**: List of available routes with metrics
- **Selection Indicator**: Shows currently selected route
- **Route Metrics**: Time and distance for each option
- **Route Numbering**: Clear identification of each route

---

## Usage Guidelines

### Color Usage

1. **Primary Blue** - Use for primary actions, navigation elements, and active states
2. **Secondary Purple** - Use for haptic mode indicators and secondary actions
3. **Success Green** - Use for arrival states and positive confirmations
4. **Warning Orange** - Use for turn indicators and cautionary states
5. **Error Red** - Use for destructive actions and error states

### Typography Hierarchy

1. **Large Title** - Main screen titles and hero text
2. **Title 1** - Section headers and important labels
3. **Title 2** - Subsection headers and metric values
4. **Headline** - Card titles and instruction text
5. **Body** - Default text content
6. **Subheadline** - Secondary information
7. **Caption** - Metadata and helper text

### Spacing Consistency

- Use consistent spacing tokens throughout the application
- Maintain visual rhythm with standardized spacing increments
- Apply appropriate spacing for component density and hierarchy

### Component Composition

- Combine components thoughtfully to create cohesive interfaces
- Maintain consistent styling patterns across similar use cases
- Use design tokens to ensure visual consistency

---

## Accessibility

### Touch Targets

All interactive elements meet minimum touch target sizes:
- **Minimum**: 44pt (DesignTokens.Accessibility.minimumTouchTarget)
- **Preferred**: 48pt (DesignTokens.Accessibility.preferredTouchTarget)

### Color Contrast

- All text maintains sufficient color contrast ratios
- Interactive elements provide clear visual distinction
- Color is not the only method of conveying information

### VoiceOver Support

- All components support VoiceOver navigation
- Meaningful labels and hints are provided
- Interactive elements are properly identified

### Dynamic Type

- Typography scales appropriately with user preferences
- Layout adapts to larger text sizes
- Content remains readable at all scale factors

### Haptic Feedback

- Provides alternative interaction methods for users with visual impairments
- Graceful fallback when haptic capabilities are unavailable
- Clear mode switching between visual and haptic interfaces

---

## Design System Maintenance

### Adding New Components

1. Follow established naming conventions
2. Use design tokens for all styling properties
3. Include comprehensive documentation
4. Provide usage examples and previews
5. Ensure accessibility compliance

### Updating Existing Components

1. Maintain backward compatibility when possible
2. Update documentation to reflect changes
3. Test across different device sizes and accessibility settings
4. Validate against design specifications

### Best Practices

- Always use design tokens instead of hardcoded values
- Maintain consistent component APIs
- Provide clear and comprehensive documentation
- Include accessibility considerations from the start
- Test components in real-world usage scenarios 