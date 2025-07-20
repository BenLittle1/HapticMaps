import Foundation
import AVFoundation
import Combine
import UIKit

/// Service responsible for accessibility features and alternative feedback mechanisms
@MainActor
class AccessibilityService: ObservableObject {
    static let shared = AccessibilityService()
    
    @Published var isVoiceOverEnabled: Bool
    @Published var isReduceMotionEnabled: Bool
    @Published var isDarkerSystemColorsEnabled: Bool
    @Published var isReduceTransparencyEnabled: Bool
    @Published var preferredContentSizeCategory: UIContentSizeCategory
    
    // Alternative feedback preferences
    @Published var isAudioFeedbackEnabled: Bool = true
    @Published var isSpeechFeedbackEnabled: Bool = true
    @Published var isVisualFeedbackEnabled: Bool = true
    
    private var speechSynthesizer: AVSpeechSynthesizer
    private var audioFeedbackPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        self.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        self.speechSynthesizer = AVSpeechSynthesizer()
        
        setupAccessibilityObservers()
        setupAudioSession()
    }
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - VoiceOver Announcements
    
    func announceAccessibility(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        guard isVoiceOverEnabled else { return }
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    func announceFocusChange(to element: String) {
        announceAccessibility(element, priority: .layoutChanged)
    }
    
    func announceScreenChange(to description: String) {
        announceAccessibility(description, priority: .screenChanged)
    }
    
    // MARK: - Speech Feedback (Alternative to Haptic)
    
    func speakNavigationInstruction(_ instruction: String, distance: String? = nil) {
        guard isSpeechFeedbackEnabled else { return }
        
        var fullInstruction = instruction
        if let distance = distance {
            fullInstruction = "In \(distance), \(instruction)"
        }
        
        let utterance = AVSpeechUtterance(string: fullInstruction)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 0.8
        
        speechSynthesizer.speak(utterance)
    }
    
    func speakNavigationMode(_ mode: NavigationMode) {
        guard isSpeechFeedbackEnabled else { return }
        
        let message = switch mode {
        case .visual:
            "Visual navigation mode enabled"
        case .haptic:
            "Haptic navigation mode enabled"
        }
        
        speakNavigationInstruction(message)
    }
    
    func speakArrival() {
        guard isSpeechFeedbackEnabled else { return }
        speakNavigationInstruction("You have arrived at your destination")
    }
    
    // MARK: - Audio Feedback (Alternative to Haptic)
    
    func playAudioCue(for pattern: HapticPattern) {
        guard isAudioFeedbackEnabled else { return }
        
        let soundName = switch pattern {
        case .turnLeft:
            "turn_left_audio"
        case .turnRight:
            "turn_right_audio"
        case .continueStraight:
            "continue_straight_audio"
        case .arrival:
            "arrival_audio"
        }
        
        playSystemSound(named: soundName)
    }
    
    private func playSystemSound(named soundName: String) {
        // Use system sounds as fallback
        let systemSoundID: SystemSoundID = switch soundName {
        case "turn_left_audio":
            1104 // SMS tone 4
        case "turn_right_audio":
            1105 // SMS tone 5
        case "continue_straight_audio":
            1003 // Key press click
        case "arrival_audio":
            1013 // Tweet
        default:
            1000 // Default system sound
        }
        
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
    // MARK: - Visual Feedback (Alternative to Haptic)
    
    func showVisualCue(for pattern: HapticPattern, in view: UIView) {
        guard isVisualFeedbackEnabled else { return }
        
        let color = switch pattern {
        case .turnLeft:
            UIColor.systemOrange
        case .turnRight:
            UIColor.systemOrange
        case .continueStraight:
            UIColor.systemBlue
        case .arrival:
            UIColor.systemGreen
        }
        
        // Create a subtle visual flash
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = color.withAlphaComponent(0.3)
        flashView.alpha = 0
        view.addSubview(flashView)
        
        UIView.animate(withDuration: 0.3, animations: {
            flashView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func isLargeTextEnabled() -> Bool {
        return preferredContentSizeCategory >= .accessibilityMedium
    }
    
    func shouldUseHighContrast() -> Bool {
        return isDarkerSystemColorsEnabled || isReduceTransparencyEnabled
    }
    
    func shouldReduceMotion() -> Bool {
        return isReduceMotionEnabled
    }
    
    func getAccessibleFontScale() -> CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall, .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.1
        case .extraLarge:
            return 1.2
        case .extraExtraLarge:
            return 1.3
        case .extraExtraExtraLarge:
            return 1.4
        case .accessibilityMedium:
            return 1.6
        case .accessibilityLarge:
            return 1.8
        case .accessibilityExtraLarge:
            return 2.0
        case .accessibilityExtraExtraLarge:
            return 2.2
        case .accessibilityExtraExtraExtraLarge:
            return 2.4
        default:
            return 1.0
        }
    }
}

// MARK: - Haptic Fallback Delegate Implementation

extension AccessibilityService: HapticFallbackDelegate {
    func hapticFeedbackUnavailable(pattern: HapticPattern, reason: HapticNavigationError) {
        announceAccessibility(DesignTokens.Accessibility.Announcements.hapticUnavailable)
        
        // Provide alternative feedback
        playAudioCue(for: pattern)
        
        // Speak the navigation instruction if appropriate
        let instruction = switch pattern {
        case .turnLeft:
            "Turn left"
        case .turnRight:
            "Turn right"
        case .continueStraight:
            "Continue straight"
        case .arrival:
            "You have arrived"
        }
        speakNavigationInstruction(instruction)
    }
    
    func playAudioFallback(for pattern: HapticPattern) {
        playAudioCue(for: pattern)
    }
    
    func showVisualFallback(for pattern: HapticPattern) {
        // This would need a view reference, so we'll handle this in the UI layer
        announceAccessibility("Visual navigation cue: \(pattern)")
    }
} 