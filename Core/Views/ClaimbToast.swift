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
    
    private let maxWidth: CGFloat = 340
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 20, height: 20)
            
            Text(message)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)
        .frame(maxWidth: maxWidth)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.cardBorder.opacity(0.3), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

