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
    @State private var networkDiagnostics: [String: Any] = [:]
    @State private var isRunningDiagnostics = false

    private struct DiagnosticItem: Identifiable {
        let id: String
        let key: String
        let value: Any
    }
    
    private var diagnosticItems: [DiagnosticItem] {
        networkDiagnostics.map { DiagnosticItem(id: $0.key, key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Test Results")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: runNetworkDiagnostics) {
                    HStack(spacing: 4) {
                        if isRunningDiagnostics {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Network Test")
                    }
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .cornerRadius(4)
                }
                .disabled(isRunningDiagnostics)
            }

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

            // Network diagnostics results  
            if !networkDiagnostics.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                Text("Network Diagnostics")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Network diagnostics: \(networkDiagnostics.count) tests completed")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func runNetworkDiagnostics() {
        isRunningDiagnostics = true
        networkDiagnostics = [:]

        Task {
            let proxyService = ProxyService()
            let results = await proxyService.performNetworkDiagnostics()

            await MainActor.run {
                networkDiagnostics = results
                isRunningDiagnostics = false
            }
        }
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
