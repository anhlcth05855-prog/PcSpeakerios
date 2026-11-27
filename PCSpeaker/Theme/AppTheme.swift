import SwiftUI

/// App Design System & Tokens
public enum AppTheme {
    // Primary brand colors
    public static let primary = Color(red: 0.0, green: 0.48, blue: 1.0)       // #007AFF
    public static let primaryDark = Color(red: 0.0, green: 0.34, blue: 0.70)
    public static let primaryLight = Color(red: 0.92, green: 0.96, blue: 1.0)
    
    // Backgrounds & Surfaces (adaptive for Dark and Light mode)
    public static let background = Color(UIColor.systemGroupedBackground)
    public static let surface = Color(UIColor.secondarySystemGroupedBackground)
    public static let surfaceVariant = Color(UIColor.tertiarySystemGroupedBackground)
    public static let border = Color(UIColor.separator)
    
    // Status colors
    public static let statusGreen = Color(red: 0.06, green: 0.73, blue: 0.51)  // #10B981
    public static let statusGreenBg = Color(red: 0.93, green: 0.99, blue: 0.96)
    public static let statusAmber = Color(red: 0.96, green: 0.62, blue: 0.04)  // #F59E0B
    public static let statusRed = Color(red: 0.94, green: 0.27, blue: 0.27)    // #EF4444
    public static let statusGray = Color(red: 0.58, green: 0.64, blue: 0.72)   // #94A3B8
    
    // VU Meter Gradients
    public static let vuGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.75, blue: 1.0),   // Electric Cyan
            Color(red: 0.06, green: 0.73, blue: 0.51), // Emerald Green
            Color(red: 0.96, green: 0.62, blue: 0.04), // Amber Peak
            Color(red: 0.94, green: 0.27, blue: 0.27)  // Red Overload
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let primaryButtonGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.48, blue: 1.0),
            Color(red: 0.0, green: 0.38, blue: 0.88)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark ? Color(white: 0.12) : Color.white)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.1) : Color(red: 0.89, green: 0.91, blue: 0.94),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    public func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
