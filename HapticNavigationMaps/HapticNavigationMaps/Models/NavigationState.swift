import Foundation

/// Represents the current state of navigation
enum NavigationState: Equatable {
    case idle
    case calculating
    case navigating(mode: NavigationMode)
    case arrived
}

/// Represents the navigation mode
enum NavigationMode: String, CaseIterable {
    case visual = "visual"
    case haptic = "haptic"
    
    var displayName: String {
        switch self {
        case .visual:
            return "Visual"
        case .haptic:
            return "Haptic"
        }
    }
}