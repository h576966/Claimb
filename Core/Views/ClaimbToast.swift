//
//  ClaimbToast.swift
//  Claimb
//
//  Created by AI Assistant
//

import SwiftUI

struct ClaimbToast: View {
    let message: String
    let systemImage: String
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.accent)
            
            Text(message)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

