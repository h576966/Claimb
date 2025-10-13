//
//  LoginView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftData
import SwiftUI

// MARK: - Loading State

enum LoginLoadingState: Equatable {
    case idle
    case fetchingSummoner
    case loadingChampions
    case loadingMatches(progress: Int, total: Int)
    case complete

    var message: String {
        switch self {
        case .idle:
            return ""
        case .fetchingSummoner:
            return "Fetching summoner data..."
        case .loadingChampions:
            return "Loading champion data..."
        case .loadingMatches(let progress, let total):
            if total > 0 {
                return "Loading matches (\(progress)/\(total))..."
            } else {
                return "Loading matches..."
            }
        case .complete:
            return "Complete!"
        }
    }

    var progress: Double {
        switch self {
        case .idle:
            return 0.0
        case .fetchingSummoner:
            return 0.25
        case .loadingChampions:
            return 0.5
        case .loadingMatches(let current, let total):
            if total > 0 {
                let matchProgress = Double(current) / Double(total) * 0.4
                return 0.6 + matchProgress
            }
            return 0.7
        case .complete:
            return 1.0
        }
    }
}

struct LoginView: View {
    let userSession: UserSession
    @State private var gameName = ""
    @State private var tagLine = ""
    @State private var selectedRegion = "euw1"
    @State private var loadingState: LoginLoadingState = .idle
    @State private var errorMessage: String?
    @State private var showOnboarding = false

    private let regions = [
        ("euw1", "Europe West"),
        ("na1", "North America"),
        ("eun1", "Europe Nordic & East"),
    ]

    // Common tagline suggestions (only supported regions)
    private let taglineSuggestions = [
        "EUW", "NA1", "EUNE",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                DesignSystem.Colors.background.ignoresSafeArea()

                if loadingState != .idle {
                    // Loading View with Progress
                    loadingView
                } else {
                    // Login Form
                    loginFormView
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            onboardingView
        }
    }

    // MARK: - Login Form View

    private var loginFormView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // App Icon and Title
            VStack(spacing: DesignSystem.Spacing.lg) {
                // App Icon
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .background(DesignSystem.Colors.background)
                    .cornerRadius(DesignSystem.CornerRadius.medium)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Claimb")
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Ranked Performance & AI Coaching")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.top, DesignSystem.Spacing.xxl)

            // Login Form
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Game Name Input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Summoner Name")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .font(DesignSystem.Typography.title3)

                    ZStack(alignment: .leading) {
                        if gameName.isEmpty {
                            Text("Enter your summoner name")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(DesignSystem.Spacing.md)
                        }
                        TextField("", text: $gameName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .accentColor(DesignSystem.Colors.primary)
                            .padding(DesignSystem.Spacing.md)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .accessibilityLabel("Summoner Name")
                            .accessibilityHint("Enter your Riot Games summoner name")
                            .submitLabel(.next)
                    }
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
                }

                // Tag Line Input with Suggestions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Tag Line")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .font(DesignSystem.Typography.title3)

                    ZStack(alignment: .leading) {
                        if tagLine.isEmpty {
                            Text("Enter your Riot ID tag")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(DesignSystem.Spacing.md)
                        }
                        TextField("", text: $tagLine)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .accentColor(DesignSystem.Colors.primary)
                            .padding(DesignSystem.Spacing.md)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .accessibilityLabel("Tag Line")
                            .accessibilityHint("Enter your Riot ID tag, like EUW or NA1")
                            .submitLabel(.done)
                            .onSubmit {
                                if isValidInput {
                                    Task { await login() }
                                }
                            }
                    }
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )

                    // Quick suggestions for tagline
                    if tagLine.isEmpty || tagLine.count < 4 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(filteredTaglineSuggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        tagLine = suggestion
                                    }) {
                                        Text(suggestion)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, DesignSystem.Spacing.xs)
                                            .background(DesignSystem.Colors.surface)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                    }
                                }
                            }
                        }
                    }
                }

                // Region Selection
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Region")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .font(DesignSystem.Typography.title3)

                    Picker("Region", selection: $selectedRegion) {
                        ForEach(regions, id: \.0) { region in
                            Text(region.1).tag(region.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .accentColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                    )
                    .accessibilityLabel("Region")
                    .accessibilityHint("Select your League of Legends region")
                }

                // Login Button
                Button(action: {
                    Task { await login() }
                }) {
                    Text("Login")
                        .font(DesignSystem.Typography.bodyBold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(PlainButtonStyle())
                .background(isValidInput ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBackground)
                .foregroundColor(DesignSystem.Colors.white)
                .cornerRadius(DesignSystem.CornerRadius.small)
                .disabled(!isValidInput)
                .opacity(isValidInput ? 1.0 : 0.5)
                .accessibilityLabel("Login")
                .accessibilityHint(
                    "Authenticate with Riot Games to view your match history and stats")

                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(DesignSystem.Colors.error)
                        .font(DesignSystem.Typography.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            // Footer
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Supported Regions: EUW, NA, EUNE")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Text("Data is cached locally for offline use")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Spinner
            ClaimbSpinner(size: 100)

            // Loading message
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(loadingState.message)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.cardBackground)
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: geometry.size.width * loadingState.progress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: loadingState.progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, DesignSystem.Spacing.xl)

                // Progress percentage
                Text("\(Int(loadingState.progress * 100))%")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            // Onboarding tip during loading
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("💡 Did you know?")
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primary)

                Text(loadingTip)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .onAppear {
            // Show full onboarding after loading completes
            if loadingState == .complete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showOnboarding = true
                }
            }
        }
    }

    // MARK: - Onboarding View

    private var onboardingView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Welcome
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 60))
                            .foregroundColor(DesignSystem.Colors.primary)

                        Text("Welcome to Claimb!")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Your personal League of Legends coach")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)

                    // Feature cards
                    VStack(spacing: DesignSystem.Spacing.md) {
                        OnboardingFeatureCard(
                            icon: "chart.bar.fill",
                            title: "Performance Analytics",
                            description:
                                "Track your KPIs and compare against role-specific baselines"
                        )

                        OnboardingFeatureCard(
                            icon: "person.3.fill",
                            title: "Champion Pool",
                            description:
                                "Analyze your champion performance and get optimization insights"
                        )

                        OnboardingFeatureCard(
                            icon: "brain.head.profile",
                            title: "AI Coaching",
                            description:
                                "Get personalized post-game analysis with specific timing-based advice"
                        )

                        OnboardingFeatureCard(
                            icon: "wifi.slash",
                            title: "Offline-First",
                            description:
                                "All your data is cached locally. Works without internet after initial sync"
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)

                    // Get Started button
                    Button(action: {
                        showOnboarding = false
                    }) {
                        Text("Get Started")
                            .font(DesignSystem.Typography.bodyBold)
                            .frame(maxWidth: .infinity)
                    }
                    .claimbButton(variant: .primary, size: .large)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        showOnboarding = false
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isValidInput: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tagLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredTaglineSuggestions: [String] {
        if tagLine.isEmpty {
            // Show region-matched suggestions first
            let regionMatched: [String]
            switch selectedRegion {
            case "euw1": regionMatched = ["EUW"]
            case "na1": regionMatched = ["NA1"]
            case "eun1": regionMatched = ["EUNE"]
            default: regionMatched = []
            }
            return regionMatched
                + taglineSuggestions.filter { !regionMatched.contains($0) }.prefix(5)
        } else {
            // Filter based on input
            return taglineSuggestions.filter {
                $0.lowercased().contains(tagLine.lowercased())
            }
        }
    }

    private var loadingTip: String {
        switch loadingState {
        case .fetchingSummoner:
            return "Claimb analyzes your last 100 matches to provide insights"
        case .loadingChampions:
            return "We load 171 champions with role-specific baselines"
        case .loadingMatches:
            return "Your match data is cached locally for offline access"
        default:
            return "All your data stays on your device - privacy first!"
        }
    }

    // MARK: - Methods

    private func login() async {
        guard isValidInput else { return }

        errorMessage = nil
        loadingState = .fetchingSummoner

        // Create DataManager
        let dataManager = DataManager.shared(with: userSession.modelContext)

        // Create or update summoner
        let summonerState = await dataManager.createOrUpdateSummoner(
            gameName: gameName.trimmingCharacters(in: .whitespacesAndNewlines),
            tagLine: tagLine.trimmingCharacters(in: .whitespacesAndNewlines),
            region: selectedRegion
        )

        // Handle summoner creation result
        guard case .loaded(let summoner) = summonerState else {
            let errorMsg: String
            switch summonerState {
            case .error(let error):
                errorMsg = ErrorHandler.userFriendlyMessage(for: error)
            case .loading:
                errorMsg = "Summoner creation is still loading"
            case .idle:
                errorMsg = "Summoner creation not started"
            case .empty(let message):
                errorMsg = message
            case .loaded:
                errorMsg = "Unknown error occurred"
            }

            await MainActor.run {
                self.errorMessage = errorMsg
                self.loadingState = .idle
            }
            return
        }

        // Load champion data
        await MainActor.run {
            loadingState = .loadingChampions
        }

        _ = await dataManager.loadChampions()

        // Load matches with progress
        await MainActor.run {
            loadingState = .loadingMatches(progress: 0, total: 100)
        }

        let refreshState = await dataManager.refreshMatches(for: summoner)

        // Simulate progress updates (DataManager doesn't expose progress yet)
        await MainActor.run {
            loadingState = .loadingMatches(progress: 50, total: 100)
        }

        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

        await MainActor.run {
            loadingState = .loadingMatches(progress: 100, total: 100)
        }

        if case .error(let error) = refreshState {
            // Log the error but don't fail login if only match loading fails
            ClaimbLogger.error(
                "Failed to load some matches during login, continuing anyway",
                service: "LoginView",
                error: error
            )
        }

        // Complete
        await MainActor.run {
            loadingState = .complete
        }

        // Small delay before transitioning
        try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s

        // Login the user
        await MainActor.run {
            ClaimbLogger.debug("About to call userSession.login()", service: "LoginView")
            userSession.login(summoner: summoner)
            ClaimbLogger.debug(
                "userSession.login() completed", service: "LoginView",
                metadata: [
                    "isLoggedIn": String(userSession.isLoggedIn)
                ])
            loadingState = .idle

            // Show onboarding for first-time users
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                showOnboarding = true
            }
        }
    }
}

// MARK: - Onboarding Feature Card

struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    let modelContainer = try! ModelContainer(
        for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self)
    let userSession = UserSession(modelContext: modelContainer.mainContext)
    LoginView(userSession: userSession)
        .modelContainer(modelContainer)
}
