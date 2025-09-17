//
//  TestResultView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// Reusable test result display component
struct TestResultView: View {
    let results: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Results")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if results.isEmpty {
                Text("No test results yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
            } else {
                ForEach(results, id: \.self) { result in
                    HStack(alignment: .top, spacing: 8) {
                        Image(
                            systemName: result.hasPrefix("✅")
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(result.hasPrefix("✅") ? .green : .red)
                        .font(.caption)

                        Text(result)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

#Preview {
    TestResultView(results: [
        "✅ Baseline data loaded successfully",
        "✅ Performance analysis completed",
        "❌ Error: Missing champion data",
    ])
    .padding()
    .background(DesignSystem.Colors.background)
}
