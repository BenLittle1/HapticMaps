import SwiftUI

/// A styled button component for map interactions following design system patterns
struct MapButton: View {
    let action: () -> Void
    let icon: String
    let label: String?
    let style: MapButtonStyle
    let size: MapButtonSize
    let isEnabled: Bool
    
    @State private var isPressed = false
    
    init(
        action: @escaping () -> Void,
        icon: String,
        label: String? = nil,
        style: MapButtonStyle = .primary,
        size: MapButtonSize = .medium,
        isEnabled: Bool = true
    ) {
        self.action = action
        self.icon = icon
        self.label = label
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        if let label = label {
            return label
        } else {
            return accessibilityLabelForIcon(icon)
        }
    }
    
    private var accessibilityHint: String {
        switch style {
        case .primary:
            return "Primary action button"
        case .secondary:
            return "Secondary action button"
        case .tertiary:
            return "Tertiary action button"
        case .destructive:
            return "Destructive action - use with caution"
        case .ghost:
            return "Action button"
        }
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        
        if style == .destructive {
            traits.formUnion([.allowsDirectInteraction])
        }
        
        return traits
    }
    
    private func accessibilityLabelForIcon(_ iconName: String) -> String {
        switch iconName {
        case "location.fill", "location":
            return "Location"
        case "play.fill", "play":
            return "Start"
        case "stop.fill", "stop":
            return "Stop"
        case "pause.fill", "pause":
            return "Pause"
        case "magnifyingglass":
            return "Search"
        case "map":
            return "Map"
        case "person.fill", "person":
            return "Profile"
        case "gear", "gearshape.fill":
            return "Settings"
        case "plus":
            return "Add"
        case "minus":
            return "Remove"
        case "arrow.left":
            return "Back"
        case "arrow.right":
            return "Forward"
        case "xmark":
            return "Close"
        default:
            return "Button"
        }
    }
    
    var body: some View {
        Button(action: {
            action()
            // Provide haptic feedback for button press if haptics are available
            if UIDevice.current.userInterfaceIdiom == .phone {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }) {
            HStack(spacing: size.iconSpacing) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(style.foregroundColor(isEnabled: isEnabled))
                
                if let label = label {
                    Text(label)
                        .accessibleFont(size.font)
                        .fontWeight(.medium)
                        .foregroundColor(style.foregroundColor(isEnabled: isEnabled))
                }
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor(isEnabled: isEnabled, isPressed: isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(
                        style.borderColor(isEnabled: isEnabled), 
                        lineWidth: UIAccessibility.isDarkerSystemColorsEnabled ? 
                            DesignTokens.Accessibility.highContrastBorderWidth : 
                            style.borderWidth
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: style.shadowColor(isEnabled: isEnabled),
                radius: style.shadowRadius,
                x: style.shadowOffset.width,
                y: style.shadowOffset.height
            )
        }
        .disabled(!isEnabled)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: CGFloat.infinity, pressing: { pressing in
            if UIAccessibility.isReduceMotionEnabled {
                isPressed = pressing
            } else {
                withAnimation(DesignTokens.Animation.quick) {
                    isPressed = pressing
                }
            }
        }, perform: {})
    }
}

// MARK: - MapButton Styles

enum MapButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
    
    func backgroundColor(isEnabled: Bool, isPressed: Bool) -> Color {
        guard isEnabled else {
            return DesignTokens.Colors.surface
        }
        
        let baseColor: Color
        switch self {
        case .primary:
            baseColor = DesignTokens.Colors.primary
        case .secondary:
            baseColor = DesignTokens.Colors.surface
        case .tertiary:
            baseColor = DesignTokens.Colors.background
        case .destructive:
            baseColor = DesignTokens.Colors.error
        case .ghost:
            baseColor = Color.clear
        }
        
        return isPressed ? baseColor.opacity(0.8) : baseColor
    }
    
    func foregroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else {
            return DesignTokens.Colors.textTertiary
        }
        
        switch self {
        case .primary, .destructive:
            return DesignTokens.Colors.textInverse
        case .secondary, .tertiary, .ghost:
            return DesignTokens.Colors.textPrimary
        }
    }
    
    func borderColor(isEnabled: Bool) -> Color {
        guard isEnabled else {
            return DesignTokens.Colors.border
        }
        
        switch self {
        case .primary, .destructive, .ghost:
            return Color.clear
        case .secondary:
            return DesignTokens.Colors.border
        case .tertiary:
            return DesignTokens.Colors.separator
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .primary, .destructive, .ghost:
            return 0
        case .secondary, .tertiary:
            return 1
        }
    }
    
    func shadowColor(isEnabled: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        
        switch self {
        case .primary, .destructive:
            return Color.black.opacity(0.1)
        case .secondary, .tertiary, .ghost:
            return Color.clear
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .primary, .destructive:
            return 4
        case .secondary, .tertiary, .ghost:
            return 0
        }
    }
    
    var shadowOffset: CGSize {
        switch self {
        case .primary, .destructive:
            return CGSize(width: 0, height: 2)
        case .secondary, .tertiary, .ghost:
            return .zero
        }
    }
}

// MARK: - MapButton Sizes

enum MapButtonSize {
    case small
    case medium
    case large
    case compact
    
    var iconSize: CGFloat {
        switch self {
        case .small:
            return DesignTokens.IconSize.sm
        case .medium:
            return DesignTokens.IconSize.md
        case .large:
            return DesignTokens.IconSize.lg
        case .compact:
            return DesignTokens.IconSize.xs
        }
    }
    
    var font: Font {
        switch self {
        case .small:
            return DesignTokens.Typography.caption1
        case .medium:
            return DesignTokens.Typography.subheadline
        case .large:
            return DesignTokens.Typography.headline
        case .compact:
            return DesignTokens.Typography.caption2
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return DesignTokens.Spacing.md
        case .medium:
            return DesignTokens.Spacing.lg
        case .large:
            return DesignTokens.Spacing.xl
        case .compact:
            return DesignTokens.Spacing.sm
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return DesignTokens.Spacing.sm
        case .medium:
            return DesignTokens.Spacing.md
        case .large:
            return DesignTokens.Spacing.lg
        case .compact:
            return DesignTokens.Spacing.xs
        }
    }
    
    var minHeight: CGFloat {
        switch self {
        case .small:
            return DesignTokens.ButtonStyle.compactHeight
        case .medium:
            return DesignTokens.ButtonStyle.secondaryHeight
        case .large:
            return DesignTokens.ButtonStyle.primaryHeight
        case .compact:
            return 24
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small, .medium, .large:
            return DesignTokens.CornerRadius.button
        case .compact:
            return DesignTokens.CornerRadius.sm
        }
    }
    
    var iconSpacing: CGFloat {
        switch self {
        case .small, .compact:
            return DesignTokens.Spacing.xs
        case .medium:
            return DesignTokens.Spacing.sm
        case .large:
            return DesignTokens.Spacing.md
        }
    }
}

// MARK: - Convenience Initializers

extension MapButton {
    /// Create a primary action button
    static func primary(
        action: @escaping () -> Void,
        icon: String,
        label: String? = nil,
        size: MapButtonSize = .medium,
        isEnabled: Bool = true
    ) -> MapButton {
        MapButton(
            action: action,
            icon: icon,
            label: label,
            style: .primary,
            size: size,
            isEnabled: isEnabled
        )
    }
    
    /// Create a secondary action button
    static func secondary(
        action: @escaping () -> Void,
        icon: String,
        label: String? = nil,
        size: MapButtonSize = .medium,
        isEnabled: Bool = true
    ) -> MapButton {
        MapButton(
            action: action,
            icon: icon,
            label: label,
            style: .secondary,
            size: size,
            isEnabled: isEnabled
        )
    }
    
    /// Create a compact icon-only button for map overlays
    static func mapOverlay(
        action: @escaping () -> Void,
        icon: String,
        isEnabled: Bool = true
    ) -> MapButton {
        MapButton(
            action: action,
            icon: icon,
            label: nil,
            style: .secondary,
            size: .compact,
            isEnabled: isEnabled
        )
    }
    
    /// Create a floating action button
    static func floating(
        action: @escaping () -> Void,
        icon: String,
        size: MapButtonSize = .medium,
        isEnabled: Bool = true
    ) -> MapButton {
        MapButton(
            action: action,
            icon: icon,
            label: nil,
            style: .primary,
            size: size,
            isEnabled: isEnabled
        )
    }
    
    /// Create a destructive action button
    static func destructive(
        action: @escaping () -> Void,
        icon: String,
        label: String? = nil,
        size: MapButtonSize = .medium,
        isEnabled: Bool = true
    ) -> MapButton {
        MapButton(
            action: action,
            icon: icon,
            label: label,
            style: .destructive,
            size: size,
            isEnabled: isEnabled
        )
    }
}

// MARK: - Preview

#Preview("Map Button Styles") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Primary buttons
        HStack(spacing: DesignTokens.Spacing.md) {
            MapButton.primary(action: {}, icon: "location.fill", label: "My Location")
            MapButton.primary(action: {}, icon: "magnifyingglass", label: "Search")
        }
        
        // Secondary buttons
        HStack(spacing: DesignTokens.Spacing.md) {
            MapButton.secondary(action: {}, icon: "map", label: "Map Type")
            MapButton.secondary(action: {}, icon: "gearshape.fill", label: "Settings")
        }
        
        // Map overlay buttons
        HStack(spacing: DesignTokens.Spacing.md) {
            MapButton.mapOverlay(action: {}, icon: "plus")
            MapButton.mapOverlay(action: {}, icon: "minus")
            MapButton.mapOverlay(action: {}, icon: "location.north")
        }
        
        // Floating action buttons
        HStack(spacing: DesignTokens.Spacing.md) {
            MapButton.floating(action: {}, icon: "location.fill")
            MapButton.floating(action: {}, icon: "plus.circle.fill", size: .large)
        }
        
        // Destructive button
        MapButton.destructive(action: {}, icon: "stop.fill", label: "Stop Navigation")
        
        // Disabled states
        HStack(spacing: DesignTokens.Spacing.md) {
            MapButton.primary(action: {}, icon: "location.fill", label: "Disabled", isEnabled: false)
            MapButton.secondary(action: {}, icon: "map", label: "Disabled", isEnabled: false)
        }
    }
    .padding(DesignTokens.Spacing.xl)
    .background(DesignTokens.Colors.surface)
}

#Preview("Map Button Sizes") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        MapButton.primary(action: {}, icon: "location.fill", label: "Large", size: .large)
        MapButton.primary(action: {}, icon: "location.fill", label: "Medium", size: .medium)
        MapButton.primary(action: {}, icon: "location.fill", label: "Small", size: .small)
        MapButton.primary(action: {}, icon: "location.fill", label: "Compact", size: .compact)
    }
    .padding(DesignTokens.Spacing.xl)
    .background(DesignTokens.Colors.surface)
} 