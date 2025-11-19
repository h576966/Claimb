//
//  ShimmerView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-11-02.
//

import SwiftUI

/// A shimmer loading effect for text placeholders
public struct ShimmerView: View {
    let lines: Int
    
    @State private var phase: CGFloat = 0
    
    public init(lines: Int = 3) {
        self.lines = lines
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<lines, id: \.self) { index in
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(shimmerGradient)
                    .frame(height: 12)
                    .frame(maxWidth: index == lines - 1 ? .infinity * 0.7 : .infinity) // Last line shorter
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: DesignSystem.Colors.cardBorder.opacity(0.3), location: 0),
                .init(color: DesignSystem.Colors.cardBorder.opacity(0.5), location: phase),
                .init(color: DesignSystem.Colors.cardBorder.opacity(0.3), location: 1)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview("Shimmer View") {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()
        VStack {
            ShimmerView(lines: 3)
                .padding()
        }
    }
}









