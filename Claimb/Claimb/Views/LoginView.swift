//
//  LoginView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var gameName = ""
    @State private var tagLine = "8778"
    @State private var selectedRegion = "euw1"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMainApp = false
    @State private var currentSummoner: Summoner?
    
    private let regions = [
        ("euw1", "Europe West"),
        ("na1", "North America"),
        ("eun1", "Europe Nordic & East")
    ]
    
    private let riotClient = RiotHTTPClient(apiKey: "RGAPI-2133e577-bec8-433b-b519-b3ba66331263")
    private let dataDragonService = DataDragonService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Title
                    VStack(spacing: 10) {
                        Text("Claimb")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("League of Legends Coaching")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                    
                    // Login Form
                    VStack(spacing: 20) {
                        // Game Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summoner Name")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            TextField("Enter your summoner name", text: $gameName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Tag Line Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tag Line")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            TextField("Enter your tag", text: $tagLine)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Region Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Region")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Picker("Region", selection: $selectedRegion) {
                                ForEach(regions, id: \.0) { region in
                                    Text(region.1).tag(region.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Login Button
                        Button(action: {
                            Task { await login() }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Login")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.black)
                            .padding()
                            .background(isValidInput ? Color.teal : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isValidInput || isLoading)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // Footer
                    VStack(spacing: 10) {
                        Text("Supported Regions: EUW, NA, EUNE")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Data is cached locally for offline use")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            if let summoner = currentSummoner {
                MainAppView(summoner: summoner)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidInput: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tagLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Methods
    
    private func login() async {
        guard isValidInput else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create DataManager
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )
            
            // Create or update summoner
            let summoner = try await dataManager.createOrUpdateSummoner(
                gameName: gameName.trimmingCharacters(in: .whitespacesAndNewlines),
                tagLine: tagLine.trimmingCharacters(in: .whitespacesAndNewlines),
                region: selectedRegion
            )
            
            // Load champion data if needed
            try await dataManager.loadChampionData()
            
            // Refresh matches
            try await dataManager.refreshMatches(for: summoner)
            
            await MainActor.run {
                self.currentSummoner = summoner
                self.isLoading = false
                self.showMainApp = true
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Login failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    LoginView()
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
