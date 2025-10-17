//
//  SharedHeaderView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI

struct SharedHeaderView: View {
    let summoner: Summoner
    let actionButton: ActionButton?
    let onLogout: (() -> Void)?

    @State private var showLogoutConfirmation = false

    struct ActionButton {
        let title: String
        let icon: String
        let action: () -> Void
        let isLoading: Bool
        let isDisabled: Bool
    }

    init(
        summoner: Summoner,
        actionButton: ActionButton? = nil,
        onLogout: (() -> Void)? = nil
    ) {
        self.summoner = summoner
        self.actionButton = actionButton
        self.onLogout = onLogout
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main navigation content
            HStack(spacing: DesignSystem.Spacing.md) {
                // Summoner Info (Left side)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(summoner.gameName)
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("#\(summoner.tagLine)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Level \(summoner.summonerLevel ?? 0)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        // Future: Rank badge would go here
                        // RankBadge(rank: summoner.rank)
                    }
                }

                Spacer()

                // Action Button (Right side) - Icon only
                if let actionButton = actionButton {
                    Button(action: actionButton.action) {
                        if actionButton.isLoading {
                            ClaimbInlineSpinner(size: 20)
                        } else {
                            Image(systemName: actionButton.icon)
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
                    .disabled(actionButton.isDisabled || actionButton.isLoading)
                    .accessibilityLabel(actionButton.isLoading ? "Refreshing" : actionButton.title)
                    .accessibilityHint("Fetches latest match data from Riot Games")
                }

                // Logout Button (if provided) - Icon only with confirmation
                if onLogout != nil {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
                    .accessibilityLabel("Account")
                    .accessibilityHint("View account options and logout")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)

            // Divider line
            Rectangle()
                .fill(DesignSystem.Colors.cardBorder)
                .frame(height: 0.5)
        }
        .background(DesignSystem.Colors.background)
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                onLogout?()
            }
        } message: {
            Text(
                "Are you sure you want to logout? You'll need to sign in again to access your data."
            )
        }
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
        SharedHeaderView(
            summoner: summoner,
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { ClaimbLogger.debug("Refresh tapped", service: "SharedHeaderView") },
                isLoading: false,
                isDisabled: false
            ),
            onLogout: { ClaimbLogger.debug("Logout tapped", service: "SharedHeaderView") }
        )

        Spacer()
    }
    .background(DesignSystem.Colors.background)
}
