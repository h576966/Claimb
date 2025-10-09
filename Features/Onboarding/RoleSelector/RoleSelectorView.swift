//
//  RoleSelectorView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-10.
//

import SwiftData
import SwiftUI

/// A reusable role selector component that displays role statistics and allows role selection
/// Supports both compact (inline) and full-screen selection modes
struct RoleSelectorView: View {
    @Binding var selectedRole: String
    let roleStats: [RoleStats]
    let onTap: () -> Void
    let showFullScreen: Bool

    // MARK: - Initialization

    init(
        selectedRole: Binding<String>, roleStats: [RoleStats], onTap: @escaping () -> Void,
        showFullScreen: Bool = false
    ) {
        self._selectedRole = selectedRole
        self.roleStats = roleStats
        self.onTap = onTap
        self.showFullScreen = showFullScreen
    }

    // MARK: - View Body

    var body: some View {
        if showFullScreen {
            fullScreenView
        } else {
            compactView
        }
    }

    // MARK: - Compact View (Inline Selection)

    private var compactView: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Role Icon
                RoleIconView(role: selectedRole, size: 32, isSelected: true)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Primary Role")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(RoleUtils.displayName(for: selectedRole))
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    Text("Win Rate & Games")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if let selectedRoleStat = roleStats.first(where: { $0.role == selectedRole }) {
                        WinRateDisplayView(
                            winRate: selectedRoleStat.winRate,
                            totalGames: selectedRoleStat.totalGames,
                            isCompact: true
                        )
                    } else {
                        Text("No games")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
        .accessibilityLabel("Primary Role: \(RoleUtils.displayName(for: selectedRole))")
        .accessibilityHint("Tap to change your primary role")
    }

    // MARK: - Full Screen View (Role Selection)

    private var fullScreenView: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Select Primary Role")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Choose your main role to see personalized insights")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.lg)

                // Role Selection Layout - Primary role on top, others below
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Primary role at the top center
                        if let primaryRoleStat = roleStats.first(where: { $0.role == selectedRole }) {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Current Selection")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)

                                RoleSelectionCard(
                                    role: selectedRole,
                                    winRate: primaryRoleStat.winRate,
                                    totalGames: primaryRoleStat.totalGames,
                                    isSelected: true,
                                    isDisabled: false,
                                    action: {
                                        // Primary role is already selected, no action needed
                                    }
                                )
                            }
                        }

                        // Other roles sorted by games played (most to least)
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Available Roles")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DesignSystem.Spacing.lg)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ], spacing: DesignSystem.Spacing.md
                            ) {
                                ForEach(sortedOtherRoles, id: \.role) { sortedRole in
                                    let roleStat =
                                        roleStats.first(where: { $0.role == sortedRole.role })
                                        ?? RoleStats(role: sortedRole.role, winRate: 0.0, totalGames: 0)
                                    let hasGames = roleStat.totalGames > 0

                                    RoleSelectionCard(
                                        role: sortedRole.role,
                                        winRate: roleStat.winRate,
                                        totalGames: roleStat.totalGames,
                                        isSelected: false,
                                        isDisabled: !hasGames,
                                        action: {
                                            if hasGames {
                                                selectedRole = sortedRole.role
                                                onTap()  // This will dismiss the sheet
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        // Help text for disabled roles
                        if sortedOtherRoles.contains(where: { $0.totalGames == 0 }) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "info.circle")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)

                                Text("Roles with no games are disabled. Play some games in a role to unlock it.")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.top, DesignSystem.Spacing.sm)
                        }

                        Spacer()
                            .frame(height: DesignSystem.Spacing.xl)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onTap()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// All available roles in the game
    private var allRoles: [String] {
        ["TOP", "JUNGLE", "MID", "BOTTOM", "SUPPORT"]
    }

    /// Roles other than the currently selected one
    private var otherRoles: [String] {
        allRoles.filter { $0 != selectedRole }
    }

    /// Other roles sorted by games played (most to least), with role info
    private var sortedOtherRoles: [(role: String, totalGames: Int)] {
        otherRoles.map { role in
            let roleStat = roleStats.first(where: { $0.role == role })
            return (role: role, totalGames: roleStat?.totalGames ?? 0)
        }
        .sorted { $0.totalGames > $1.totalGames }
    }

}

// MARK: - Reusable Components

/// A reusable role icon component that handles both custom images and fallback icons
struct RoleIconView: View {
    let role: String
    let size: CGFloat
    let isSelected: Bool
    let isDisabled: Bool

    init(role: String, size: CGFloat, isSelected: Bool, isDisabled: Bool = false) {
        self.role = role
        self.size = size
        self.isSelected = isSelected
        self.isDisabled = isDisabled
    }

    var body: some View {
        Image(RoleUtils.iconName(for: role))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundColor(iconColor)
            .opacity(isDisabled ? 0.4 : 1.0)
    }

    private var iconColor: Color {
        if isDisabled {
            return DesignSystem.Colors.textTertiary
        } else if isSelected {
            return DesignSystem.Colors.primary
        } else {
            return DesignSystem.Colors.textSecondary
        }
    }
}

/// A reusable win rate display component
struct WinRateDisplayView: View {
    let winRate: Double
    let totalGames: Int
    let isCompact: Bool
    let isDisabled: Bool

    init(
        winRate: Double, totalGames: Int, isCompact: Bool, isDisabled: Bool = false
    ) {
        self.winRate = winRate
        self.totalGames = totalGames
        self.isCompact = isCompact
        self.isDisabled = isDisabled
    }

    var body: some View {
        VStack(spacing: isCompact ? 2 : DesignSystem.Spacing.xs) {
            if totalGames > 0 {
                Text("\(Int(winRate * 100))%")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isDisabled ? DesignSystem.Colors.textTertiary : winRateColor)
                    .opacity(isDisabled ? 0.5 : 1.0)

                Text("\(totalGames) \(totalGames == 1 ? "game" : "games")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .opacity(isDisabled ? 0.5 : 1.0)
            } else {
                Text("—")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Text("No games")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }

    private var winRateColor: Color {
        let colorName = RoleUtils.winRateColor(winRate)
        switch colorName {
        case "accent": return DesignSystem.Colors.accent
        case "textSecondary": return DesignSystem.Colors.textSecondary
        case "primary": return DesignSystem.Colors.primary
        case "secondary": return DesignSystem.Colors.secondary
        default: return DesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Role Selection Card Component

/// A reusable card component for displaying role selection options
struct RoleSelectionCard: View {
    let role: String
    let winRate: Double
    let totalGames: Int
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        role: String,
        winRate: Double,
        totalGames: Int,
        isSelected: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.role = role
        self.winRate = winRate
        self.totalGames = totalGames
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.action = action
    }

    // MARK: - View Body

    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Role Icon
                RoleIconView(role: role, size: 48, isSelected: isSelected, isDisabled: isDisabled)

                // Role Name
                Text(RoleUtils.displayName(for: role))
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(textColor)
                    .opacity(isDisabled ? 0.5 : 1.0)

                // Win Rate and Games (or disabled state)
                if isDisabled {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("Play some games")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                } else {
                    WinRateDisplayView(
                        winRate: winRate,
                        totalGames: totalGames,
                        isCompact: false,
                        isDisabled: isDisabled
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(backgroundFill)
            .overlay(borderOverlay)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Computed Properties

    private var textColor: Color {
        if isDisabled {
            return DesignSystem.Colors.textTertiary
        } else if isSelected {
            return DesignSystem.Colors.primary
        } else {
            return DesignSystem.Colors.textPrimary
        }
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isDisabled {
            return DesignSystem.Colors.cardBackground.opacity(0.5)
        } else if isSelected {
            return DesignSystem.Colors.primary.opacity(0.1)
        } else {
            return DesignSystem.Colors.cardBackground
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        if isDisabled {
            return DesignSystem.Colors.cardBorder.opacity(0.5)
        } else if isSelected {
            return DesignSystem.Colors.primary
        } else {
            return DesignSystem.Colors.cardBorder
        }
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    private var accessibilityLabel: String {
        let roleName = RoleUtils.displayName(for: role)
        if isDisabled {
            return "\(roleName) - No games played"
        } else if isSelected {
            return "\(roleName) - Currently selected"
        } else {
            return "\(roleName) - \(totalGames) games, \(Int(winRate * 100))% win rate"
        }
    }

    private var accessibilityHint: String {
        if isDisabled {
            return "This role is disabled because you haven't played any games in it yet"
        } else if isSelected {
            return "This is your currently selected primary role"
        } else {
            return "Double tap to select this as your primary role"
        }
    }

}

// MARK: - Preview

#Preview("With Mixed Stats") {
    let roleStats = [
        RoleStats(role: "TOP", winRate: 0.65, totalGames: 20),
        RoleStats(role: "JUNGLE", winRate: 0.45, totalGames: 15),
        RoleStats(role: "MID", winRate: 0.70, totalGames: 25),
        RoleStats(role: "BOTTOM", winRate: 0.55, totalGames: 18),
        RoleStats(role: "SUPPORT", winRate: 0.0, totalGames: 0),  // No games
    ]

    RoleSelectorView(
        selectedRole: .constant("MID"),
        roleStats: roleStats,
        onTap: { ClaimbLogger.debug("Navigate to role selection", service: "RoleSelectorView") }
    )
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Full Screen") {
    let roleStats = [
        RoleStats(role: "TOP", winRate: 0.65, totalGames: 20),
        RoleStats(role: "JUNGLE", winRate: 0.0, totalGames: 0),  // No games
        RoleStats(role: "MID", winRate: 0.70, totalGames: 25),
        RoleStats(role: "BOTTOM", winRate: 0.55, totalGames: 5),
        RoleStats(role: "SUPPORT", winRate: 0.0, totalGames: 0),  // No games
    ]

    RoleSelectorView(
        selectedRole: .constant("MID"),
        roleStats: roleStats,
        onTap: { ClaimbLogger.debug("Dismiss", service: "RoleSelectorView") },
        showFullScreen: true
    )
}
