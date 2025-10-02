//
//  SharedHeaderView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI

struct SharedHeaderView: View {
    let summoner: Summoner
    let title: String
    let actionButton: ActionButton?
    let onLogout: (() -> Void)?

    struct ActionButton {
        let title: String
        let icon: String
        let action: () -> Void
        let isLoading: Bool
        let isDisabled: Bool
    }

    init(
        summoner: Summoner,
        title: String,
        actionButton: ActionButton? = nil,
        onLogout: (() -> Void)? = nil
    ) {
        self.summoner = summoner
        self.title = title
        self.actionButton = actionButton
        self.onLogout = onLogout
    }

    var body: some View {
        CustomNavigationBar(
            summoner: summoner,
            title: title,
            actionButton: actionButton.map { actionButton in
                CustomNavigationBar.ActionButton(
                    title: actionButton.title,
                    icon: actionButton.icon,
                    action: actionButton.action,
                    isLoading: actionButton.isLoading,
                    isDisabled: actionButton.isDisabled
                )
            },
            onLogout: onLogout
        )
    }
}

#Preview {
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )

    SharedHeaderView(
        summoner: summoner,
        title: "Test View",
        actionButton: SharedHeaderView.ActionButton(
            title: "Refresh",
            icon: "arrow.clockwise",
            action: { ClaimbLogger.debug("Refresh tapped", service: "SharedHeaderView") },
            isLoading: false,
            isDisabled: false
        ),
        onLogout: { ClaimbLogger.debug("Logout tapped", service: "SharedHeaderView") }
    )
    .background(DesignSystem.Colors.background)
}
