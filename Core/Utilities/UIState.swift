//
//  UIState.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import SwiftUI

/// Standardized UI state management for consistent loading, error, and empty states
public enum UIState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    case empty(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    public var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }

    public var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }

    public var emptyMessage: String? {
        if case .empty(let message) = self { return message }
        return nil
    }
}

/// Standardized loading view component using ClaimbSpinner
public struct ClaimbLoadingView: View {
    public let message: String
    public let size: CGFloat

    public init(message: String = "Loading...", size: CGFloat = 120) {
        self.message = message
        self.size = size
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlowCSpinner(size: size)

            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

/// Simple inline loading indicator using ClaimbSpinner
public struct ClaimbInlineSpinner: View {
    public let size: CGFloat

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        GlowCSpinner(size: size)
    }
}

/// Standardized error view component
public struct ClaimbErrorView: View {
    public let error: Error
    public let retryAction: (() -> Void)?

    public init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.error)

            Text("Something went wrong")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(ErrorHandler.userFriendlyMessage(for: error))
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if let retryAction = retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(ClaimbButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

/// Standardized empty state view component
public struct ClaimbEmptyView: View {
    public let message: String
    public let systemImage: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        message: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: systemImage)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(message)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(ClaimbButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

/// Standardized content wrapper that handles all UI states
public struct ClaimbContentWrapper<Content: View, Data>: View {
    public let state: UIState<Data>
    public let loadingMessage: String
    public let emptyMessage: String
    public let emptySystemImage: String
    public let retryAction: (() -> Void)?
    public let content: (Data) -> Content

    public init(
        state: UIState<Data>,
        loadingMessage: String = "Loading...",
        emptyMessage: String = "No data available",
        emptySystemImage: String = "tray",
        retryAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Data) -> Content
    ) {
        self.state = state
        self.loadingMessage = loadingMessage
        self.emptyMessage = emptyMessage
        self.emptySystemImage = emptySystemImage
        self.retryAction = retryAction
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            ClaimbLoadingView(message: loadingMessage)

        case .loaded(let data):
            content(data)

        case .error(let error):
            ClaimbErrorView(error: error, retryAction: retryAction)

        case .empty(let message):
            ClaimbEmptyView(
                message: message.isEmpty ? emptyMessage : message,
                systemImage: emptySystemImage,
                actionTitle: retryAction != nil ? "Refresh" : nil,
                action: retryAction
            )
        }
    }
}

/// Convenience initializers for common UI states
extension UIState {
    public static func loading() -> UIState<T> {
        return .loading
    }

    public static func success(_ data: T) -> UIState<T> {
        return .loaded(data)
    }

    public static func failure(_ error: Error) -> UIState<T> {
        return .error(error)
    }

    public static func noData(_ message: String = "No data available") -> UIState<T> {
        return .empty(message)
    }
}
