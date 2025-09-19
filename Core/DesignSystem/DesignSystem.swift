import SwiftUI

// MARK: - Design System
// Apple Watch-like interface with dark card-based layouts
// Clean typography, data visualization, and minimalistic design

struct DesignSystem {

    // MARK: - Colors
    struct Colors {
        // Primary brand colors
        static let primary = Color(red: 240 / 255, green: 160 / 255, blue: 10 / 255)  // Orange
        static let secondary = Color(red: 220 / 255, green: 100 / 255, blue: 70 / 255)  // Red-orange
        static let accent = Color(red: 100 / 255, green: 210 / 255, blue: 155 / 255)  // Teal

        // Standard colors
        static let black = Color.black
        static let white = Color.white
        static let gray = Color.gray

        // Semantic colors
        static let background = Color.black
        static let cardBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
        static let cardBorder = Color(red: 0.2, green: 0.2, blue: 0.2)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.8, green: 0.8, blue: 0.8)
        static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.6)

        // Status colors (using brand colors)
        static let success = Color(red: 100 / 255, green: 210 / 255, blue: 155 / 255)  // Teal (accent)
        static let warning = Color(red: 240 / 255, green: 160 / 255, blue: 10 / 255)  // Orange (primary)
        static let error = Color(red: 220 / 255, green: 100 / 255, blue: 70 / 255)  // Red-orange (secondary)
        static let info = Color(red: 0.8, green: 0.8, blue: 0.8)  // Light grey (textSecondary)
    }

    // MARK: - Typography
    struct Typography {
        // Headers
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .semibold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 20, weight: .medium, design: .default)

        // Body text
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)

        // Special
        static let monospaced = Font.system(size: 17, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
    }

    // MARK: - Shadows
    struct Shadows {
        static let card = Color.black.opacity(0.3)
        static let cardRadius: CGFloat = 8
        static let cardOffset = CGSize(width: 0, height: 4)
    }
}

// MARK: - Card Components
struct ClaimbCard<Content: View>: View {
    let content: Content
    let padding: CGFloat

    init(padding: CGFloat = DesignSystem.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Shadows.card,
                radius: DesignSystem.Shadows.cardRadius,
                x: DesignSystem.Shadows.cardOffset.width,
                y: DesignSystem.Shadows.cardOffset.height
            )
    }
}

// MARK: - Button Styles
struct ClaimbButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: ButtonSize

    enum ButtonVariant {
        case primary
        case secondary
        case minimal
    }

    enum ButtonSize {
        case small
        case medium
        case large
    }

    init(variant: ButtonVariant = .primary, size: ButtonSize = .medium) {
        self.variant = variant
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .foregroundColor(buttonTextColor)
            .padding(buttonPadding)
            .background(buttonBackground)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonFont: Font {
        switch size {
        case .small: return DesignSystem.Typography.callout
        case .medium: return DesignSystem.Typography.body
        case .large: return DesignSystem.Typography.title3
        }
    }

    private var buttonPadding: EdgeInsets {
        switch size {
        case .small: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .medium: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        }
    }

    private var buttonTextColor: Color {
        switch variant {
        case .primary: return DesignSystem.Colors.white
        case .secondary: return DesignSystem.Colors.primary
        case .minimal: return DesignSystem.Colors.textPrimary
        }
    }

    private var buttonBackground: Color {
        switch variant {
        case .primary: return DesignSystem.Colors.primary
        case .secondary: return DesignSystem.Colors.cardBackground
        case .minimal: return Color.clear
        }
    }
}

// MARK: - Rating System
struct ClaimbRating {
    enum Level: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"

        var color: Color {
            switch self {
            case .excellent: return DesignSystem.Colors.success  // Teal
            case .good: return DesignSystem.Colors.accent  // Teal (same as success)
            case .fair: return DesignSystem.Colors.warning  // Orange
            case .poor: return DesignSystem.Colors.error  // Red-orange
            }
        }
    }

    static func level(for score: Double, maxScore: Double = 100) -> Level {
        let percentage = score / maxScore
        switch percentage {
        case 0.8...: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .fair
        default: return .poor
        }
    }
}

// MARK: - Data Visualization
struct ClaimbProgressBar: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let height: CGFloat

    init(
        value: Double, maxValue: Double = 100, color: Color = DesignSystem.Colors.primary,
        height: CGFloat = 8
    ) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(DesignSystem.Colors.cardBorder)
                    .frame(height: height)

                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * (value / maxValue), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Extensions
extension View {
    func claimbCard(padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        ClaimbCard(padding: padding) {
            self
        }
    }

    func claimbButton(
        variant: ClaimbButtonStyle.ButtonVariant = .primary,
        size: ClaimbButtonStyle.ButtonSize = .medium
    ) -> some View {
        self.buttonStyle(ClaimbButtonStyle(variant: variant, size: size))
    }
}
