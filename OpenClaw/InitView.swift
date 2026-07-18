//
//  InitView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI
import Network

struct InitView: View {
    @EnvironmentObject private var gateway: GatewayClient
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionRequested = false

    var body: some View {
        RootView()
        .task {
            requestLocalNetworkPermissionIfNeeded()
            gateway.connect()
        }
        .onChange(of: scenePhase) { phase in
            gateway.handleScenePhase(phase)
        }
    }

    private func requestLocalNetworkPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        LocalNetworkPermissionRequester.request()
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MainChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            NavigationStack {
                SettingBarView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}
