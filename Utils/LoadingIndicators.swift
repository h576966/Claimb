//
//  LoadingIndicators.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import SwiftUI
import Foundation

/// Standardized loading indicators for consistent UI across the app
public struct ClaimbLoadingIndicators {
    
    /// Small inline loading indicator for buttons and small spaces
    public static func inline(size: CGFloat = 16) -> some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            .scaleEffect(size / 20) // Scale to desired size
    }
    
    /// Medium loading indicator for cards and sections
    public static func card(size: CGFloat = 40) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                .scaleEffect(size / 20)
            
            Text("Loading...")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    /// Full-screen loading indicator with custom message
    public static func fullScreen(message: String = "Loading...", size: CGFloat = 120) -> some View {
        ClaimbLoadingView(message: message, size: size)
    }
    
    /// Skeleton loading view for content placeholders
    public static func skeleton(width: CGFloat? = nil, height: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
            .fill(DesignSystem.Colors.cardBackground)
            .frame(width: width, height: height)
            .shimmer()
    }
    
    /// Skeleton card for match cards, champion cards, etc.
    public static func skeletonCard() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header skeleton
            HStack {
                ClaimbLoadingIndicators.skeleton(width: 60, height: 16)
                Spacer()
                ClaimbLoadingIndicators.skeleton(width: 40, height: 16)
            }
            
            // Content skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ClaimbLoadingIndicators.skeleton(width: 200, height: 14)
                ClaimbLoadingIndicators.skeleton(width: 150, height: 14)
                ClaimbLoadingIndicators.skeleton(width: 180, height: 14)
            }
            
            // Footer skeleton
            HStack {
                ClaimbLoadingIndicators.skeleton(width: 80, height: 12)
                Spacer()
                ClaimbLoadingIndicators.skeleton(width: 60, height: 12)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

/// Shimmer effect modifier for skeleton loading
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.cardBackground,
                        DesignSystem.Colors.cardBackground.opacity(0.3),
                        DesignSystem.Colors.cardBackground
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .onAppear {
                phase = 1
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Loading state wrapper for async operations
@MainActor
public class LoadingState: ObservableObject {
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var lastRefreshTime: Date?
    
    public init() {}
    
    public func setLoading(_ loading: Bool) {
        isLoading = loading
        if !loading {
            lastRefreshTime = Date()
        }
    }
    
    public func setError(_ error: Error?) {
        self.error = error
    }
    
    public func clearError() {
        error = nil
    }
    
    public func reset() {
        isLoading = false
        error = nil
        lastRefreshTime = nil
    }
}

/// Async operation wrapper with loading states
public struct AsyncOperation<Content: View>: View {
    @StateObject private var loadingState = LoadingState()
    private let operation: () async throws -> Void
    private let content: (LoadingState) -> Content
    
    public init(
        operation: @escaping () async throws -> Void,
        @ViewBuilder content: @escaping (LoadingState) -> Content
    ) {
        self.operation = operation
        self.content = content
    }
    
    public var body: some View {
        content(loadingState)
            .task {
                await performOperation()
            }
    }
    
    private func performOperation() async {
        loadingState.setLoading(true)
        loadingState.clearError()
        
        do {
            try await operation()
        } catch {
            loadingState.setError(error)
            ClaimbLogger.error("Async operation failed", service: "AsyncOperation", error: error)
        }
        
        loadingState.setLoading(false)
    }
}
