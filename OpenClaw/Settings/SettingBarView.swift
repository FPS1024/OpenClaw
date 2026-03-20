//
//  SettingBarView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI

struct SettingBarView: View {
    var body: some View {
        List {
            Section("Account") {
                NavigationLink(destination: GatewayView()) {
                    SettingRow(title: "Gateway", icon: "antenna.radiowaves.left.and.right", showsChevron: true)
                }

                NavigationLink(destination: RemoteView()) {
                    SettingRow(title: "Remote", icon: "dot.radiowaves.left.and.right", showsChevron: true)
                }
                SettingRow(title: "Subscription", icon: "creditcard")
            }

            Section("Preferences") {
                SettingToggle(title: "Dark Mode", icon: "moon.fill", isOn: false)
                SettingToggle(title: "Sound Effects", icon: "speaker.wave.2.fill", isOn: true)
                SettingRow(title: "Language", icon: "globe")
            }

            Section("Support") {
                SettingRow(title: "Help Center", icon: "questionmark.circle")
                SettingRow(title: "Send Feedback", icon: "envelope")
                NavigationLink(destination: AboutView()) {
                    SettingRow(title: "About", icon: "info.circle", showsChevron: true)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingRow: View {
    let title: String
    let icon: String
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundColor(Color.accentColor)
            Text(title)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingToggle: View {
    let title: String
    let icon: String
    @State var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 28, height: 28)
                    .foregroundColor(Color.accentColor)
                Text(title)
            }
        }
    }
}
