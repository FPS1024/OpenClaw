//
//  OpenClawApp.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI
@main
struct OpenClawApp: App {
    @StateObject private var gateway = GatewayClient()

    var body: some Scene {
        WindowGroup {
            InitView()
                .environmentObject(gateway)
        }
    }
}
