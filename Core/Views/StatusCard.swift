//
//  StatusCard.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// Reusable status card component for displaying metrics
struct StatusCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(value)
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusCard(title: "Baselines Loaded", value: "42", color: .teal)
        StatusCard(title: "Champion Mappings", value: "156", color: .orange)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
