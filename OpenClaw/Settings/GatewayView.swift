//
//  GatewayView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI

struct GatewayView: View {
    @EnvironmentObject private var gateway: GatewayClient

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Host")
                    Spacer()
                    TextField("Host", text: $gateway.host)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", text: $gateway.portText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use TLS", isOn: $gateway.useTLS)
                HStack {
                    Text("Token")
                    Spacer()
                    SecureField("Gateway Token", text: $gateway.token)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Button(action: toggleConnection) {
                        Text(buttonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                Button(role: .destructive) {
                    gateway.resetDeviceIdentity()
                } label: {
                    Text("Reset Device Identity")
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Status") {
                HStack {
                    Text("State")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                HStack {
                    Text("Last Event")
                    Spacer()
                    Text(lastEventText)
                        .foregroundColor(.secondary)
                }
                if let error = errorText {
                    HStack {
                        Text("Error")
                        Spacer()
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .navigationTitle("Gateway")
        .onDisappear {
            gateway.persistSettings()
        }
    }

    private var statusText: String {
        switch gateway.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        switch gateway.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .secondary
        case .error: return .red
        }
    }

    private var lastEventText: String {
        if let date = gateway.lastEventAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "—"
    }

    private var errorText: String? {
        if case let .error(message) = gateway.connectionState {
            return message
        }
        return nil
    }

    private var buttonTitle: String {
        switch gateway.connectionState {
        case .connected: return "Disconnect"
        case .connecting: return "Connecting…"
        default: return "Connect"
        }
    }

    private func toggleConnection() {
        switch gateway.connectionState {
        case .connected:
            gateway.disconnect()
        case .connecting:
            return
        default:
            gateway.connect()
        }
    }
}
