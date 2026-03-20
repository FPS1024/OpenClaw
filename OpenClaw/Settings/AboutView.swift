//
//  AboutView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/20.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard
                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return short ?? "Beta-1.0"
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image("AppIconPreview")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("OpenClaw")
                .font(.title3)
            Text("Current Version \(appVersion)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warning")
                .font(.headline)
                .foregroundColor(.red)
            Text("You are using the beta version app. You can get new releases on GitHub.")
                .font(.headline)
                .foregroundColor(.red)
            Text("OpenClaw is a lightweight iOS client for the OpenClaw gateway. It provides real‑time chat with WebSocket connectivity, auto‑reconnect, and streaming responses in a clean, native SwiftUI interface.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Statement:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("The icon and project name \"OpenClaw\" belong to      https://github.com/openclaw/openclaw and its community/official repository owners.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Github: https://github.com/fps1024/OpenClaw")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("© 2026 Kaysarjan·Kasim. Released under MIT License.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Thanks:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Special thanks to contributors and the open source community!")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

}

struct LinkRow: View {
    let title: String
    let value: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}
