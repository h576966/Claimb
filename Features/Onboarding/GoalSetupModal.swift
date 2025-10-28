//
//  GoalSetupModal.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftData
import SwiftUI

/// Modal for setting up user goals with KPI selection and focus type
struct GoalSetupModal: View {
    // MARK: - Properties
    
    let topKPIs: [KPIMetric]
    let isFirstTime: Bool
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Champion.name) private var allChampions: [Champion]
    
    // MARK: - State
    
    @State private var selectedKPI: KPIMetric?
    @State private var selectedFocusType: FocusType = .climbing
    @State private var selectedChampion: Champion?
    @State private var selectedRole: String?
    @State private var isLoading = false
    
    private let allRoles = ["TOP", "JUNGLE", "MID", "BOTTOM", "SUPPORT"]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                headerSection
                
                // Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // KPI Selection
                        kpiSelectionSection
                        
                        // Focus Type Selection
                        focusTypeSection
                        
                        // Learning Context (conditional)
                        if selectedFocusType == .learning {
                            learningContextSection
                        }
                        
                        // Action Buttons
                        actionButtonsSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
        .onAppear {
            initializeDefaultSelections()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "target")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.accent)
            
            Text(isFirstTime ? "Set Your Goal" : "Update Your Goal")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(isFirstTime 
                 ? "Choose what you'd like to focus on to improve your gameplay" 
                 : "It's time for your weekly goal check-in")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    // MARK: - KPI Selection Section
    
    private var kpiSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Focus Area")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Select the area that needs the most improvement")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(topKPIs, id: \.metric) { kpi in
                    kpiOptionCard(kpi: kpi)
                }
            }
        }
        .claimbCard()
    }
    
    private func kpiOptionCard(kpi: KPIMetric) -> some View {
        Button(action: {
            selectedKPI = kpi
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Selection indicator
                Image(systemName: selectedKPI?.metric == kpi.metric ? "checkmark.circle.fill" : "circle")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(selectedKPI?.metric == kpi.metric ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(kpi.displayName)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Current: \(kpi.value)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("•")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Text(kpi.performanceLevel.displayName)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(kpi.color)
                    }
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                selectedKPI?.metric == kpi.metric 
                    ? DesignSystem.Colors.accent.opacity(0.1) 
                    : DesignSystem.Colors.cardBackground
            )
            .cornerRadius(DesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(
                        selectedKPI?.metric == kpi.metric 
                            ? DesignSystem.Colors.accent 
                            : DesignSystem.Colors.cardBorder, 
                        lineWidth: selectedKPI?.metric == kpi.metric ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Focus Type Section
    
    private var focusTypeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Focus Type")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Are you focusing on climbing rank or learning new champions/roles?")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(FocusType.allCases, id: \.self) { focusType in
                    focusTypeButton(focusType: focusType)
                }
            }
        }
        .claimbCard()
    }
    
    private func focusTypeButton(focusType: FocusType) -> some View {
        Button(action: {
            selectedFocusType = focusType
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: focusType == .climbing ? "arrow.up.right" : "book")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(selectedFocusType == focusType ? DesignSystem.Colors.white : DesignSystem.Colors.textSecondary)
                
                Text(focusType.displayName)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(selectedFocusType == focusType ? DesignSystem.Colors.white : DesignSystem.Colors.textSecondary)
                
                Text(focusType == .climbing ? "Improve rank" : "Learn & practice")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(selectedFocusType == focusType ? DesignSystem.Colors.white.opacity(0.8) : DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(selectedFocusType == focusType ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(
                        selectedFocusType == focusType ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Learning Context Section
    
    private var learningContextSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Learning Context")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("What are you trying to learn? (Optional)")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Champion Selection
                championSelectionSection
                
                // Role Selection
                roleSelectionSection
            }
        }
        .claimbCard()
    }
    
    private var championSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Champion")
                .font(DesignSystem.Typography.callout)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Menu {
                Button("None") {
                    selectedChampion = nil
                }
                
                ForEach(allChampions, id: \.id) { champion in
                    Button(champion.name) {
                        selectedChampion = champion
                    }
                }
            } label: {
                HStack {
                    Text(selectedChampion?.name ?? "Select Champion")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(selectedChampion != nil ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Role")
                .font(DesignSystem.Typography.callout)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Menu {
                Button("None") {
                    selectedRole = nil
                }
                
                ForEach(allRoles, id: \.self) { role in
                    Button(RoleUtils.displayName(for: role)) {
                        selectedRole = role
                    }
                }
            } label: {
                HStack {
                    Text(selectedRole != nil ? RoleUtils.displayName(for: selectedRole!) : "Select Role")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(selectedRole != nil ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Save Button
            Button(action: saveGoal) {
                HStack {
                    if isLoading {
                        ClaimbSpinner()
                            .frame(width: 16, height: 16)
                    }
                    
                    Text(isLoading ? "Saving..." : "Set Goal")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .background(canSaveGoal ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                .foregroundColor(DesignSystem.Colors.white)
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
            .disabled(!canSaveGoal || isLoading)
            .buttonStyle(PlainButtonStyle())
            
            // Skip/Cancel Button
            if !isFirstTime {
                Button("Cancel") {
                    onDismiss()
                }
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Computed Properties
    
    private var canSaveGoal: Bool {
        selectedKPI != nil
    }
    
    // MARK: - Methods
    
    private func initializeDefaultSelections() {
        // Pre-select the worst performing KPI
        if selectedKPI == nil && !topKPIs.isEmpty {
            selectedKPI = topKPIs.first
        }
    }
    
    private func saveGoal() {
        guard let kpi = selectedKPI else { return }
        
        isLoading = true
        
        // Save goal to UserGoals
        UserGoals.setCompleteGoal(
            kpiMetric: kpi.metric,
            focusType: selectedFocusType,
            learningChampion: selectedChampion?.name,
            learningRole: selectedRole
        )
        
        ClaimbLogger.info("Goal saved from modal", service: "GoalSetupModal", metadata: [
            "kpi": kpi.metric,
            "focusType": selectedFocusType.rawValue,
            "isFirstTime": String(isFirstTime)
        ])
        
        // Small delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            onComplete()
        }
    }
}

// MARK: - Preview

#Preview {
    let modelContainer = try! ModelContainer(for: Champion.self)
    
    // Mock KPI data for preview
    let mockKPIs = [
        KPIMetric(
            metric: "deaths_per_game",
            value: "5.2",
            baseline: nil,
            performanceLevel: .poor,
            color: DesignSystem.Colors.error
        ),
        KPIMetric(
            metric: "cs_per_min",
            value: "6.1",
            baseline: nil,
            performanceLevel: .needsImprovement,
            color: DesignSystem.Colors.warning
        ),
        KPIMetric(
            metric: "vision_score_per_min",
            value: "1.8",
            baseline: nil,
            performanceLevel: .needsImprovement,
            color: DesignSystem.Colors.warning
        )
    ]
    
    return GoalSetupModal(
        topKPIs: mockKPIs,
        isFirstTime: true,
        onComplete: {},
        onDismiss: {}
    )
    .modelContainer(modelContainer)
}
