//
//  MainChatView.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import SwiftUI
import MarkdownUI

struct MainChatView: View {
    @State private var inputText = ""
    @EnvironmentObject private var gateway: GatewayClient
    @FocusState private var isInputFocused: Bool
    @State private var showNewChatAlert = false
    @State private var showSessionDrawer = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                connectionBanner
                ZStack {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = false
                        }
                        .background(Color(.systemBackground))
                        .onChange(of: lastMessageId) { _ in
                            scrollToBottom(proxy, animated: true)
                        }
                        .onChange(of: lastMessageText) { _ in
                            scrollToBottom(proxy, animated: false)
                        }
                        .onAppear {
                            scrollToBottom(proxy, animated: false)
                        }
                    }
                }

                inputBar
                Divider()
            }

            // 左侧会话抽屉
            SessionDrawerView(isShowing: $showSessionDrawer)
                .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(currentSessionTitle)
                        .font(.headline)
                    StatusLight(isConnected: gateway.connectionState == .connected)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSessionDrawer.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewChatAlert = true
                } label: {
                    Label("New", systemImage: "square.and.pencil")
                }
            }
        }
        .background(Color(.systemBackground))
        .alert("开始新对话？", isPresented: $showNewChatAlert) {
            Button("取消", role: .cancel) {}
            Button("确认", role: .destructive) {
                gateway.clearMessages()
            }
        } message: {
            Text("这将清除当前会话的消息记录。")
        }
    }

    private var currentSessionTitle: String {
        gateway.availableSessions
            .first { $0.key == gateway.currentSessionKey }?
            .displayTitle ?? gateway.currentSessionKey
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch gateway.connectionState {
        case .connected:
            EmptyView()
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting to gateway…")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        case .disconnected:
            Label("Gateway is disconnected. Configure it in Settings.", systemImage: "wifi.slash")
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                // attachment action
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
            }

            TextField("Message", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .focused($isInputFocused)

            Button {
                if gateway.isStreaming {
                    gateway.abortCurrentRun()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: gateway.isStreaming ? "pause.fill" : "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .disabled((!gateway.isStreaming && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                      || gateway.connectionState != .connected)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        gateway.sendUserMessage(trimmed)
        inputText = ""
    }

    private var messages: [ChatMessage] {
        gateway.messages
    }

    private var lastMessageId: UUID? {
        messages.last?.id
    }

    private var lastMessageText: String {
        messages.last?.text ?? ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = lastMessageId else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 30) }
            bubbleContent
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(message.isUser ? .white : .primary)
                .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !message.isUser { Spacer(minLength: 30) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isUser {
            Text(message.text)
        } else {
            Markdown(message.text)
                .markdownTextStyle {
                    FontSize(15)
                }
        }
    }
}

struct StatusLight: View {
    let isConnected: Bool

    var body: some View {
        Circle()
            .fill(isConnected ? Color.green : Color.red)
            .frame(width: 10, height: 10)
            .accessibilityLabel(isConnected ? "Connected" : "Disconnected")
    }
}
