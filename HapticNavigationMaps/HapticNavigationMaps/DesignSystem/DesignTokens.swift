import SwiftUI

/// Design tokens for consistent styling across the application
/// Based on Figma specifications and existing component patterns
struct DesignTokens {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary Colors
        static let primary = Color.blue
        static let primaryLight = Color.blue.opacity(0.1)
        static let primaryDark = Color(red: 0.0, green: 0.48, blue: 0.99)
        
        // Secondary Colors
        static let secondary = Color.purple
        static let secondaryLight = Color.purple.opacity(0.1)
        
        // System Colors
        static let success = Color.green
        static let successLight = Color.green.opacity(0.1)
        static let warning = Color.orange
        static let warningLight = Color.orange.opacity(0.1)
        static let error = Color.red
        static let errorLight = Color.red.opacity(0.1)
        
        // Neutral Colors
        static let background = Color(.systemBackground)
        static let surface = Color(.systemGray6)
        static let surfaceElevated = Color(.systemBackground)
        static let border = Color(.systemGray4)
        static let separator = Color(.separator)
        
        // Text Colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(.tertiaryLabel)
        static let textInverse = Color.white
        
        // Navigation Colors
        static let navigationTurnLeft = Color.orange
        static let navigationTurnRight = Color.orange
        static let navigationStraight = Color.blue
        static let navigationArrival = Color.green
        
        // Map Colors
        static let mapPrimary = Color.blue
        static let mapSecondary = Color(.systemGray2)
        static let routeColor = Color.blue
        static let userLocationColor = Color.blue
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // Body
        static let headline = Font.headline
        static let body = Font.body
        static let bodyEmphasis = Font.body.weight(.medium)
        static let callout = Font.callout
        
        // Supporting
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption1 = Font.caption
        static let caption2 = Font.caption2
        
        // Navigation specific
        static let navigationInstruction = Font.headline
        static let navigationDistance = Font.title.weight(.bold)
        static let navigationSecondary = Font.subheadline
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        
        // Component specific spacing
        static let cardPadding: CGFloat = 20
        static let buttonPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 12
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
        
        // Component specific
        static let button: CGFloat = 12
        static let card: CGFloat = 16
        static let panel: CGFloat = 16
        static let input: CGFloat = 10
        static let toggle: CGFloat = 16
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        static let card = Shadow(
            color: Color.black.opacity(0.1),
            radius: 10,
            offset: CGSize(width: 0, height: -2)
        )
        
        static let panel = Shadow(
            color: Color.black.opacity(0.1),
            radius: 10,
            offset: CGSize(width: 0, height: -2)
        )
        
        static let button = Shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            offset: CGSize(width: 0, height: 2)
        )
        
        let color: Color
        let radius: CGFloat
        let offset: CGSize
    }
    
    // MARK: - Icon Sizes
    
    struct IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Component specific
        static let navigationInstruction: CGFloat = 28
        static let modeToggle: CGFloat = 16
        static let button: CGFloat = 16
    }
    
    // MARK: - Button Styles
    
    struct ButtonStyle {
        static let primaryHeight: CGFloat = 48
        static let secondaryHeight: CGFloat = 40
        static let compactHeight: CGFloat = 32
        
        static let primaryCornerRadius: CGFloat = CornerRadius.button
        static let pillCornerRadius: CGFloat = CornerRadius.pill
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        // Component specific
        static let modeToggle = quick
        static let panelTransition = medium
        static let searchTransition = quick
    }
    
    // MARK: - Accessibility
    
    struct Accessibility {
        static let minimumTouchTarget: CGFloat = 44
        static let preferredTouchTarget: CGFloat = 48
        
        // Dynamic Type scaling limits
        static let maxFontScale: CGFloat = 2.0
        static let minFontScale: CGFloat = 0.8
        
        // High contrast adjustments
        static let highContrastBorderWidth: CGFloat = 2.0
        static let standardBorderWidth: CGFloat = 1.0
        
        // VoiceOver announcements
        struct Announcements {
            static let navigationModeChanged = "Navigation mode changed"
            static let routeCalculated = "Route calculated"
            static let navigationStarted = "Navigation started"
            static let navigationStopped = "Navigation stopped"
            static let arrivalAnnounced = "Destination reached"
            static let hapticUnavailable = "Haptic feedback not available"
        }
        
        // Alternative feedback for haptic-disabled users
        struct AlternativeFeedback {
            static let audioEnabled = "audioFeedbackEnabled"
            static let visualEnabled = "visualFeedbackEnabled"
            static let speechEnabled = "speechFeedbackEnabled"
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling with design tokens
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.surfaceElevated)
            .cornerRadius(DesignTokens.CornerRadius.card)
            .shadow(
                color: DesignTokens.Shadow.card.color,
                radius: DesignTokens.Shadow.card.radius,
                x: DesignTokens.Shadow.card.offset.width,
                y: DesignTokens.Shadow.card.offset.height
            )
    }
    
    /// Apply panel styling with design tokens
    func panelStyle() -> some View {
        self
            .background(DesignTokens.Colors.background)
            .cornerRadius(DesignTokens.CornerRadius.panel, corners: [.topLeft, .topRight])
            .shadow(
                color: DesignTokens.Shadow.panel.color,
                radius: DesignTokens.Shadow.panel.radius,
                x: DesignTokens.Shadow.panel.offset.width,
                y: DesignTokens.Shadow.panel.offset.height
            )
    }
    
    /// Apply handle bar styling for panels
    func handleBar() -> some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(DesignTokens.Colors.border)
            .frame(width: 36, height: 5)
            .padding(.top, DesignTokens.Spacing.sm)
    }
    
    // MARK: - Accessibility Extensions
    
    /// Apply accessibility-aware font scaling
    func accessibleFont(_ font: Font) -> some View {
        self.font(font)
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    /// Apply high contrast border when needed
    @ViewBuilder
    func accessibleBorder(_ color: Color = DesignTokens.Colors.border) -> some View {
        if UIAccessibility.isDarkerSystemColorsEnabled || UIAccessibility.isReduceTransparencyEnabled {
            self.overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(color, lineWidth: DesignTokens.Accessibility.highContrastBorderWidth)
            )
        } else {
            self.overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(color, lineWidth: DesignTokens.Accessibility.standardBorderWidth)
            )
        }
    }
    
    /// Apply accessibility-optimized colors
    @ViewBuilder
    func accessibleBackgroundColor(_ color: Color) -> some View {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            self.background(color.colorMultiply(Color.black.opacity(0.3)))
        } else {
            self.background(color)
        }
    }
    
    /// Add proper touch target size for accessibility
    func accessibleTouchTarget() -> some View {
        self.frame(minWidth: DesignTokens.Accessibility.minimumTouchTarget, 
                  minHeight: DesignTokens.Accessibility.minimumTouchTarget)
    }
}

// Note: cornerRadius(_:corners:) extension and RoundedCorner shape are defined in SearchResultsView.swift 