//
//  MenuView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI

struct SessionDrawerView: View {
    @EnvironmentObject private var gateway: GatewayClient
    @Binding var isShowing: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // 半透明背景，点击关闭
            if isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                // 抽屉主体
                drawerPanel
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowing)
    }

    private var drawerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("智能体")
                    .font(.title3.bold())
                Spacer()
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if gateway.availableSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Spacer()

            // 底部刷新按钮
            Button {
                Task { await gateway.reloadSessions() }
            } label: {
                Label("刷新列表", systemImage: "arrow.clockwise")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 0)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(gateway.availableSessions) { session in
                    SessionRow(
                        session: session,
                        isSelected: session.key == gateway.currentSessionKey
                    )
                    .onTapGesture {
                        gateway.switchToSession(session.key)
                        close()
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("没有可用的智能体")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isShowing = false
        }
    }
}

struct SessionRow: View {
    let session: SessionEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : Color(.systemGray3))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                if let label = session.label, label != session.key {
                    Text(session.key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }
}
