//
//  InitView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI
import Network

struct InitView: View {
    @State private var isReady = false
    @EnvironmentObject private var gateway: GatewayClient
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionRequested = false

    var body: some View {
        Group {
            if isReady {
                RootView()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Connecting...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .task {
            await requestLocalNetworkPermissionIfNeeded()
            gateway.connect()
        }
        .onChange(of: gateway.connectionState) { _ in
            if gateway.connectionState == .connected {
                withAnimation(.easeOut(duration: 0.2)) {
                    isReady = true
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            gateway.handleScenePhase(phase)
        }
    }

    private func requestLocalNetworkPermissionIfNeeded() async {
        guard !permissionRequested else { return }
        permissionRequested = true
        await LocalNetworkPermissionRequester.request()
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
