//
//  RoleSelectorView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-10.
//

import SwiftUI
import SwiftData

struct RoleSelectorView: View {
    @Binding var selectedRole: String
    let roleStats: [RoleStats]
    let onTap: () -> Void
    let showFullScreen: Bool
    
    init(selectedRole: Binding<String>, roleStats: [RoleStats], onTap: @escaping () -> Void, showFullScreen: Bool = false) {
        self._selectedRole = selectedRole
        self.roleStats = roleStats
        self.onTap = onTap
        self.showFullScreen = showFullScreen
    }
    
    var body: some View {
        if showFullScreen {
            fullScreenView
        } else {
            compactView
        }
    }
    
    private var compactView: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Primary Role")
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("Win Rate & Games")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(roleStats, id: \.role) { roleStat in
                        RoleButton(
                            role: roleStat.role,
                            winRate: roleStat.winRate,
                            totalGames: roleStat.totalGames,
                            isSelected: selectedRole == roleStat.role,
                            action: { selectedRole = roleStat.role }
                        )
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .claimbCard()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.textSecondary, lineWidth: 1)
        )
    }
    
    private var fullScreenView: some View {
        NavigationView {
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
                
                // Role Selection Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.md) {
                    ForEach(roleStats, id: \.role) { roleStat in
                        RoleSelectionCard(
                            role: roleStat.role,
                            winRate: roleStat.winRate,
                            totalGames: roleStat.totalGames,
                            isSelected: selectedRole == roleStat.role,
                            action: {
                                selectedRole = roleStat.role
                                onTap() // This will dismiss the sheet
                            }
                        )
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
}

struct RoleButton: View {
    let role: String
    let winRate: Double
    let totalGames: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Role Icon
                if let image = UIImage(named: RoleUtils.iconName(for: role)) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                } else {
                    // Fallback to SF Symbol if role icon not found
                    Image(systemName: "person.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                }
                
                // Role Name
                Text(RoleUtils.displayName(for: role))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                // Win Rate and Game Count
                VStack(spacing: 2) {
                    Text("\(Int(winRate * 100))%")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(winRateColor)
                    
                    Text("\(totalGames) games")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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

struct RoleSelectionCard: View {
    let role: String
    let winRate: Double
    let totalGames: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Role Icon
                if let image = UIImage(named: RoleUtils.iconName(for: role)) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                }
                
                // Role Name
                Text(RoleUtils.displayName(for: role))
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)
                
                // Win Rate and Games
                VStack(spacing: 2) {
                    Text("\(Int(winRate * 100))%")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(winRateColor)
                    
                    Text("\(totalGames) games")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Preview

#Preview {
    let roleStats = [
        RoleStats(role: "TOP", winRate: 0.65, totalGames: 20),
        RoleStats(role: "JUNGLE", winRate: 0.45, totalGames: 15),
        RoleStats(role: "SOLO", winRate: 0.70, totalGames: 25),  // Using SOLO (Riot's name for mid)
        RoleStats(role: "BOTTOM", winRate: 0.55, totalGames: 18),
        RoleStats(role: "UTILITY", winRate: 0.60, totalGames: 12)
    ]
    
    return RoleSelectorView(
        selectedRole: .constant("SOLO"),
        roleStats: roleStats,
        onTap: { print("Navigate to role selection") }
    )
    .padding()
    .background(DesignSystem.Colors.background)
}
