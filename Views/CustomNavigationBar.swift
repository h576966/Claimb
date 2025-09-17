//
//  CustomNavigationBar.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI

struct CustomNavigationBar: View {
    let summoner: Summoner
    let title: String
    let actionButton: ActionButton?
    let onLogout: (() -> Void)?
    
    struct ActionButton {
        let title: String
        let icon: String
        let action: () -> Void
        let isLoading: Bool
        let isDisabled: Bool
    }
    
    init(
        summoner: Summoner, 
        title: String, 
        actionButton: ActionButton? = nil,
        onLogout: (() -> Void)? = nil
    ) {
        self.summoner = summoner
        self.title = title
        self.actionButton = actionButton
        self.onLogout = onLogout
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main navigation content
            HStack(spacing: DesignSystem.Spacing.md) {
                // Summoner Info (Left side)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summoner.gameName)#\(summoner.tagLine)")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Level \(summoner.summonerLevel ?? 0)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        // Future: Rank badge would go here
                        // RankBadge(rank: summoner.rank)
                    }
                }
                
                Spacer()
                
                // Action Button (Right side)
                if let actionButton = actionButton {
                    Button(action: actionButton.action) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if actionButton.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: actionButton.icon)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            
                            Text(actionButton.title)
                                .font(DesignSystem.Typography.caption)
                        }
                    }
                    .claimbButton(variant: .primary, size: .small)
                    .disabled(actionButton.isDisabled || actionButton.isLoading)
                }
                
                // Logout Button (if provided)
                if let onLogout = onLogout {
                    Button(action: onLogout) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            
            // Divider line
            Rectangle()
                .fill(DesignSystem.Colors.cardBorder)
                .frame(height: 0.5)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Preview
#Preview {
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )
    
    return VStack(spacing: 0) {
        CustomNavigationBar(
            summoner: summoner,
            title: "Champion Pool",
            actionButton: CustomNavigationBar.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { print("Refresh tapped") },
                isLoading: false,
                isDisabled: false
            ),
            onLogout: { print("Logout tapped") }
        )
        
        Spacer()
    }
    .background(DesignSystem.Colors.background)
}
