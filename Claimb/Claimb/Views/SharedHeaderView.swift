//
//  SharedHeaderView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI

struct SharedHeaderView: View {
    let summoner: Summoner
    let title: String
    let actionButton: ActionButton?
    
    struct ActionButton {
        let title: String
        let icon: String
        let action: () -> Void
        let isLoading: Bool
        let isDisabled: Bool
    }
    
    init(summoner: Summoner, title: String, actionButton: ActionButton? = nil) {
        self.summoner = summoner
        self.title = title
        self.actionButton = actionButton
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summoner Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summoner.gameName)#\(summoner.tagLine)")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Level \(summoner.summonerLevel ?? 0)")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Action Button (if provided)
                if let actionButton = actionButton {
                    Button(action: actionButton.action) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if actionButton.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: actionButton.icon)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(actionButton.title)
                                .font(DesignSystem.Typography.callout)
                        }
                    }
                    .claimbButton(variant: .primary, size: .small)
                    .disabled(actionButton.isDisabled || actionButton.isLoading)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
}

#Preview {
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )
    
    return SharedHeaderView(
        summoner: summoner,
        title: "Test View",
        actionButton: SharedHeaderView.ActionButton(
            title: "Refresh",
            icon: "arrow.clockwise",
            action: { print("Refresh tapped") },
            isLoading: false,
            isDisabled: false
        )
    )
    .background(DesignSystem.Colors.background)
}
