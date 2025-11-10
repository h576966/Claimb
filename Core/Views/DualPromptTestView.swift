//
//  DualPromptTestView.swift
//  Claimb
//
//  Temporary view to test dual prompt structure
//  Run this to compare single vs dual prompt responses
//

import SwiftUI

struct DualPromptTestView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    @State private var showResults = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.accent)
                        
                        Text("Dual Prompt Test")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Compare single vs dual prompt responses")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Run Test Button
                    Button(action: {
                        Task {
                            await runTests()
                        }
                    }) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isRunning ? "Running Tests..." : "Run Dual Prompt Test")
                        }
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .disabled(isRunning)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Info Card
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accent)
                            Text("What This Tests")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("This test compares two approaches for AI coaching:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                                Text("1.")
                                Text("**Single Prompt**: Instructions + data mixed together (current)")
                            }
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                                Text("2.")
                                Text("**Dual Prompt**: System instructions separate from user data (new)")
                            }
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("⚠️ This makes real API calls and will use OpenAI tokens")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.error)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Results
                    if showResults {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Test Results")
                                    .font(DesignSystem.Typography.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = testResults.joined(separator: "\n")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(testResults.indices, id: \.self) { index in
                                        Text(testResults[index])
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(resultColor(for: testResults[index]))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(DesignSystem.Spacing.sm)
                            }
                            .frame(maxHeight: 400)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Test Dual Prompt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runTests() async {
        isRunning = true
        testResults = []
        showResults = false
        
        // Add a small delay to show loading state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let results = await DualPromptTest.runDualPromptTests()
        
        testResults = results
        showResults = true
        isRunning = false
    }
    
    private func resultColor(for line: String) -> Color {
        if line.contains("✅") {
            return Color.green
        } else if line.contains("❌") {
            return Color.red
        } else if line.contains("⚠️") {
            return Color.orange
        } else if line.contains("🧪") || line.contains("📊") || line.contains("📝") {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.textSecondary
        }
    }
}

#Preview {
    DualPromptTestView()
}

