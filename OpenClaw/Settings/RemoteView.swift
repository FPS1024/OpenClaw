//
//  RemoteView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI

struct RemoteView: View {
    @State private var deviceName = "OpenClaw Remote"
    @EnvironmentObject private var gateway: GatewayClient

    var body: some View {
        Form {
            Section("Device") {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Name", text: $deviceName)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Auto Reconnect", isOn: $gateway.autoReconnectEnabled)
                Toggle("Keep Alive", isOn: $gateway.keepAliveEnabled)
            }

            Section("Info") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Idle")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Pairing")
                    Spacer()
                    Text("Ready")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Remote")
        .onChange(of: gateway.keepAliveEnabled) { _ in
            gateway.applyKeepAliveSetting()
        }
        .onChange(of: gateway.autoReconnectEnabled) { _ in
            gateway.persistSettings()
        }
    }
}
