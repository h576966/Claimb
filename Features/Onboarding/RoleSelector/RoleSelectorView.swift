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
                                action: {
                                    // Primary role is already selected, no action needed
                                }
                            )
                        }
                    }

                    // Other roles in a 2x2 grid below
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: DesignSystem.Spacing.md
                    ) {
                        ForEach(otherRoles, id: \.self) { role in
                            let roleStat =
                                roleStats.first(where: { $0.role == role })
                                ?? RoleStats(role: role, winRate: 0.0, totalGames: 0)
                            RoleSelectionCard(
                                role: role,
                                winRate: roleStat.winRate,
                                totalGames: roleStat.totalGames,
                                isSelected: false,
                                action: {
                                    selectedRole = role
                                    onTap()  // This will dismiss the sheet
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
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

}

// MARK: - Reusable Components

/// A reusable role icon component that handles both custom images and fallback icons
struct RoleIconView: View {
    let role: String
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        Image(RoleUtils.iconName(for: role))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundColor(
                isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
    }
}

/// A reusable win rate display component
struct WinRateDisplayView: View {
    let winRate: Double
    let totalGames: Int
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 2 : DesignSystem.Spacing.xs) {
            Text("\(Int(winRate * 100))%")
                .font(DesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(winRateColor)

            Text("\(totalGames) games")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
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
    let action: () -> Void

    // MARK: - View Body

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Role Icon
                RoleIconView(role: role, size: 48, isSelected: isSelected)

                // Role Name
                Text(RoleUtils.displayName(for: role))
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(
                        isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)

                // Win Rate and Games
                WinRateDisplayView(
                    winRate: winRate,
                    totalGames: totalGames,
                    isCompact: false
                )
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(
                        isSelected
                            ? DesignSystem.Colors.primary.opacity(0.1)
                            : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(
                        isSelected
                            ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

}

// MARK: - Preview

#Preview {
    let roleStats = [
        RoleStats(role: "TOP", winRate: 0.65, totalGames: 20),
        RoleStats(role: "JUNGLE", winRate: 0.45, totalGames: 15),
        RoleStats(role: "MID", winRate: 0.70, totalGames: 25),
        RoleStats(role: "BOTTOM", winRate: 0.55, totalGames: 18),
        RoleStats(role: "SUPPORT", winRate: 0.60, totalGames: 12),
    ]

    RoleSelectorView(
        selectedRole: .constant("MID"),
        roleStats: roleStats,
        onTap: { ClaimbLogger.debug("Navigate to role selection", service: "RoleSelectorView") }
    )
    .padding()
    .background(DesignSystem.Colors.background)
}
