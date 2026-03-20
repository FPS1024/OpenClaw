//
//  GatewayClient.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/20.
//

import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Security

@MainActor
final class GatewayClient: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var lastEventAt: Date?
    @Published var lastPingMs: Int?

    @Published var host: String = GatewaySettings.defaultHost
    @Published var portText: String = String(GatewaySettings.defaultPort)
    @Published var useTLS: Bool = false
    @Published var token: String = ""
    @Published var autoReconnectEnabled: Bool = true
    @Published var keepAliveEnabled: Bool = true
    @Published var isStreaming: Bool = false

    private let session = URLSession(configuration: .default)
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private let pendingResponses = PendingResponseStore()
    private var activeRunMessageIds: [String: UUID] = [:]
    private let sessionKey = "main"
    private let historyCacheKey = "chat.cache.main"

    private var deviceToken: String? {
        get { KeychainStore.loadString(service: "ai.openclaw.gateway", account: "deviceToken") }
        set {
            if let value = newValue, !value.isEmpty {
                _ = KeychainStore.saveString(value, service: "ai.openclaw.gateway", account: "deviceToken")
            } else {
                _ = KeychainStore.delete(service: "ai.openclaw.gateway", account: "deviceToken")
            }
        }
    }

    init() {
        loadSettings()
        loadCachedMessages()
    }

    func loadSettings() {
        host = GatewaySettings.loadString(.host, fallback: GatewaySettings.defaultHost)
        portText = GatewaySettings.loadString(.port, fallback: String(GatewaySettings.defaultPort))
        useTLS = GatewaySettings.loadBool(.useTLS, fallback: false)
        token = GatewaySettings.loadString(.token, fallback: "")
        autoReconnectEnabled = GatewaySettings.loadBool(.autoReconnect, fallback: true)
        keepAliveEnabled = GatewaySettings.loadBool(.keepAlive, fallback: true)
    }

    func persistSettings() {
        GatewaySettings.saveString(.host, value: host)
        GatewaySettings.saveString(.port, value: portText)
        GatewaySettings.saveBool(.useTLS, value: useTLS)
        GatewaySettings.saveString(.token, value: token)
        GatewaySettings.saveBool(.autoReconnect, value: autoReconnectEnabled)
        GatewaySettings.saveBool(.keepAlive, value: keepAliveEnabled)
    }

    private func persistMessages() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: historyCacheKey)
    }

    private func loadCachedMessages() {
        guard let data = UserDefaults.standard.data(forKey: historyCacheKey),
              let cached = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        messages = cached
    }

    func connect() {
        guard connectionState != .connecting else { return }
        persistSettings()
        Task { await connectInternal(retryOnSignatureInvalid: true) }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard autoReconnectEnabled else { return }
        switch phase {
        case .active:
            if connectionState == .disconnected || isErrorState {
                connect()
            } else if keepAliveEnabled {
                startKeepAliveLoop()
            }
        case .background, .inactive:
            keepAliveTask?.cancel()
            keepAliveTask = nil
            break
        @unknown default:
            break
        }
    }

    func applyKeepAliveSetting() {
        if keepAliveEnabled, connectionState == .connected {
            startKeepAliveLoop()
        } else {
            keepAliveTask?.cancel()
            keepAliveTask = nil
        }
        persistSettings()
    }

    func disconnect() {
        cleanupSocket()
        connectionState = .disconnected
    }

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(text: trimmed, isUser: true))
        persistMessages()
        Task { await sendChatMessage(trimmed) }
    }

    func abortCurrentRun() {
        guard connectionState == .connected else { return }
        endStreaming()
        Task {
            _ = try? await sendRequest(method: "chat.abort", params: ["sessionKey": sessionKey])
        }
    }

    func clearMessages() {
        messages.removeAll()
        persistMessages()
    }

    private func connectInternal(retryOnSignatureInvalid: Bool) async {
        connectionState = .connecting
        lastPingMs = nil
        lastEventAt = nil

        guard let port = Int(portText), port > 0, port <= 65535 else {
            connectionState = .error("Invalid port")
            return
        }

        guard let url = GatewayURLBuilder.makeURL(host: host, port: port, useTLS: useTLS) else {
            connectionState = .error("Invalid host")
            return
        }

        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()

        do {
            let challenge = try await receiveFrame()
            guard challenge["type"] as? String == "event",
                  challenge["event"] as? String == "connect.challenge",
                  let payload = challenge["payload"] as? [String: Any],
                  let nonce = payload["nonce"] as? String,
                  let ts = payload["ts"] as? Int
            else {
                throw GatewayError("Expected connect.challenge")
            }

            let identity = DeviceIdentityStore.loadOrCreate()
            let signingToken = deviceToken?.isEmpty == false ? deviceToken! : token
            let signed = DeviceIdentitySigner.sign(
                identity: identity,
                nonce: nonce,
                timestampMs: ts,
                clientId: "openclaw-ios",
                clientMode: "ui",
                platform: GatewayClientInfo.platform,
                deviceFamily: GatewayClientInfo.deviceFamily,
                role: "operator",
                scopes: GatewayScopes.operatorScopes,
                token: signingToken,
                version: .v3
            )

            let connectParams: [String: Any] = [
                "minProtocol": 3,
                "maxProtocol": 3,
                "client": GatewayClientInfo.current,
                "role": "operator",
                "scopes": GatewayScopes.operatorScopes,
                "auth": GatewayAuthParams.build(token: token, deviceToken: deviceToken),
                "device": signed,
                "locale": Locale.current.identifier,
                "userAgent": GatewayClientInfo.userAgent,
                "caps": ["tool-events"]
            ]

            let connectId = UUID().uuidString
            let connectFrame: [String: Any] = [
                "type": "req",
                "id": connectId,
                "method": "connect",
                "params": connectParams
            ]
            let connectText = try jsonString(connectFrame)
            try await socket?.send(.string(connectText))

            var response: [String: Any] = [:]
            while true {
                let frame = try await receiveFrame()
                if frame["type"] as? String == "res",
                   frame["id"] as? String == connectId {
                    response = frame
                    break
                }
            }

            if let ok = response["ok"] as? Bool, ok == false {
                let message = (response["error"] as? [String: Any])?["message"] as? String ?? "Connect failed"
                if retryOnSignatureInvalid, shouldRetryForSignatureInvalid(message: message) {
                    deviceToken = nil
                    await connectInternal(retryOnSignatureInvalid: false)
                    return
                }
                throw GatewayError(message)
            }
            if let payload = response["payload"] as? [String: Any],
               let auth = payload["auth"] as? [String: Any],
               let issued = auth["deviceToken"] as? String {
                deviceToken = issued
            }

            connectionState = .connected
            startKeepAliveLoop()
            startReceiveLoop()
            await refreshHistory()
        } catch {
            connectionState = .error(error.localizedDescription)
            cleanupSocket()
        }
    }

    private var isErrorState: Bool {
        if case .error = connectionState { return true }
        return false
    }

    private func shouldRetryForSignatureInvalid(message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("device signature invalid") || lowered.contains("signature invalid")
    }

    private func cleanupSocket() {
        receiveTask?.cancel()
        receiveTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        Task { await pendingResponses.removeAll() }
        activeRunMessageIds.removeAll()
        isStreaming = false
    }

    private func startKeepAliveLoop() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        guard keepAliveEnabled, connectionState == .connected, let socket else { return }
        keepAliveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let started = Date()
                await withCheckedContinuation { cont in
                    socket.sendPing { error in
                        Task { @MainActor in
                            if let error {
                                self.connectionState = .error(error.localizedDescription)
                                self.cleanupSocket()
                            } else {
                                self.lastPingMs = Int(Date().timeIntervalSince(started) * 1000)
                            }
                            cont.resume()
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    func resetDeviceIdentity() {
        DeviceIdentityStore.reset()
        deviceToken = nil
    }

    private func sendChatMessage(_ text: String) async {
        guard connectionState == .connected else { return }
        let params: [String: Any] = [
            "sessionKey": sessionKey,
            "message": text,
            "idempotencyKey": UUID().uuidString
        ]
        _ = try? await sendRequest(method: "chat.send", params: params)
    }

    private func refreshHistory() async {
        guard connectionState == .connected else { return }
        let params: [String: Any] = [
            "sessionKey": sessionKey,
            "limit": 100
        ]
        guard let response = try? await sendRequest(method: "chat.history", params: params),
              let payload = response["payload"] else {
            return
        }
        let history = parseHistoryPayload(payload)
        if !history.isEmpty {
            messages = history
            persistMessages()
        }
    }

    private func parseHistoryPayload(_ payload: Any) -> [ChatMessage] {
        if let dict = payload as? [String: Any], let messages = dict["messages"] as? [Any] {
            return parseHistoryMessages(messages)
        }
        if let list = payload as? [Any] {
            return parseHistoryMessages(list)
        }
        return []
    }

    private func parseHistoryMessages(_ list: [Any]) -> [ChatMessage] {
        var result: [ChatMessage] = []
        for item in list {
            guard let dict = item as? [String: Any] else { continue }
            let role = (dict["role"] as? String ?? dict["author"] as? String ?? "").lowercased()
            let isUser = role == "user" || role == "human" || role == "operator"
            if let text = extractMessageText(dict["content"] ?? dict["text"] ?? dict["message"] ?? dict) {
                result.append(ChatMessage(text: text, isUser: isUser))
            }
        }
        return result
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let frame = try await self.receiveFrame()
                    await self.handleFrame(frame)
                } catch {
                    await MainActor.run {
                        if case .connected = self.connectionState {
                            self.connectionState = .error("Disconnected")
                        }
                    }
                    break
                }
            }
        }
    }

    private func receiveFrame() async throws -> [String: Any] {
        guard let socket else { throw GatewayError("Socket not available") }
        let message = try await socket.receive()
        switch message {
        case .string(let text):
            return try parseJSON(text)
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw GatewayError("Invalid text frame")
            }
            return try parseJSON(text)
        @unknown default:
            throw GatewayError("Unknown WS message")
        }
    }

    private func parseJSON(_ text: String) throws -> [String: Any] {
        let data = Data(text.utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw GatewayError("Malformed JSON frame")
        }
        return dict
    }

    private func sendRequest(method: String, params: [String: Any]) async throws -> [String: Any] {
        let id = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req",
            "id": id,
            "method": method,
            "params": params
        ]
        let text = try jsonString(frame)
        guard let socket else {
            throw GatewayError("Socket not available")
        }
        try await socket.send(.string(text))

        return try await withCheckedThrowingContinuation { continuation in
            Task { await pendingResponses.insert(id: id, continuation: continuation) }
        }
    }

    private func jsonString(_ obj: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GatewayError("Invalid JSON encoding")
        }
        return text
    }

    private func handleFrame(_ frame: [String: Any]) async {
        lastEventAt = Date()
        guard let type = frame["type"] as? String else { return }
        if type == "res" {
            let id = frame["id"] as? String ?? ""
            if let cont = await pendingResponses.take(id: id) {
                if let ok = frame["ok"] as? Bool, ok {
                    cont.resume(returning: frame)
                } else {
                    let message = (frame["error"] as? [String: Any])?["message"] as? String ?? "Request failed"
                    cont.resume(throwing: GatewayError(message))
                }
            }
            return
        }

        guard type == "event" else { return }
        let event = frame["event"] as? String ?? ""
        if event == "tick" {
            return
        }

        if event == "chat" || event == "agent" {
            guard let payload = frame["payload"] as? [String: Any] else { return }
            if let stream = payload["stream"] as? String,
               let data = payload["data"] as? [String: Any] {
                handleStreamingEvent(payload: payload, stream: stream, data: data)
            } else {
                handleChatEvent(payload: payload)
            }
        }
    }

    private func handleStreamingEvent(payload: [String: Any], stream: String, data: [String: Any]) {
        guard stream == "assistant" else { return }
        let runId = payload["runId"] as? String ?? UUID().uuidString
        if let delta = data["delta"] as? String {
            appendAssistantDelta(runId: runId, delta: delta)
        } else if let text = data["text"] as? String {
            appendAssistantDelta(runId: runId, delta: text)
        }
    }

    private func handleChatEvent(payload: [String: Any]) {
        let runId = payload["runId"] as? String ?? UUID().uuidString
        let state = payload["state"] as? String ?? ""
        if state == "aborted" || state == "cancelled" || state == "stopped" || state == "error" {
            endStreaming()
            return
        }
        if state == "delta" {
            if let delta = extractMessageText(payload["message"]) {
                appendAssistantDelta(runId: runId, delta: delta)
            }
            return
        }

        if let messageText = extractMessageText(payload["message"]) {
            finalizeAssistantMessage(runId: runId, text: messageText)
        }
    }

    private func endStreaming() {
        activeRunMessageIds.removeAll()
        isStreaming = false
        persistMessages()
    }

    private func appendAssistantDelta(runId: String, delta: String) {
        if let messageId = activeRunMessageIds[runId],
           let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].text += delta
            persistMessages()
            return
        }
        let newMessage = ChatMessage(text: delta, isUser: false)
        activeRunMessageIds[runId] = newMessage.id
        messages.append(newMessage)
        isStreaming = true
        persistMessages()
    }

    private func finalizeAssistantMessage(runId: String, text: String) {
        if let messageId = activeRunMessageIds[runId],
           let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].text = text
        } else {
            messages.append(ChatMessage(text: text, isUser: false))
        }
        activeRunMessageIds.removeValue(forKey: runId)
        isStreaming = !activeRunMessageIds.isEmpty
        persistMessages()
    }

    private func extractMessageText(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let dict = value as? [String: Any] {
            if let text = dict["text"] as? String { return text }
            if let content = dict["content"] as? String { return content }
            if let parts = dict["parts"] as? [String] { return parts.joined() }
        }
        return nil
    }
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    let isUser: Bool

    init(text: String, isUser: Bool, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }
}

enum GatewayScopes {
    static let operatorScopes: [String] = [
        "operator.read",
        "operator.write",
        "operator.admin",
        "operator.approvals",
        "operator.pairing"
    ]
}

enum GatewayAuthParams {
    static func build(token: String, deviceToken: String?) -> [String: Any] {
        var auth: [String: Any] = [:]
        if !token.isEmpty { auth["token"] = token }
        if let deviceToken, !deviceToken.isEmpty { auth["deviceToken"] = deviceToken }
        return auth
    }
}

enum GatewayURLBuilder {
    static func makeURL(host: String, port: Int, useTLS: Bool) -> URL? {
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.hasPrefix("ws://") || cleanHost.hasPrefix("wss://") {
            cleanHost = cleanHost.replacingOccurrences(of: "ws://", with: "")
            cleanHost = cleanHost.replacingOccurrences(of: "wss://", with: "")
        }
        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = cleanHost
        components.port = port
        return components.url
    }
}

enum GatewayClientInfo {
    static var current: [String: Any] {
        [
            "id": "openclaw-ios",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
            "platform": platform,
            "mode": "ui",
            "deviceFamily": deviceFamily,
            "modelIdentifier": modelIdentifier,
            "instanceId": instanceId
        ]
    }

    static var platform: String { "ios" }

    static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return "openclaw-ios/\(version)"
    }

    static var deviceFamily: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iphone"
        case .pad: return "ipad"
        case .mac: return "mac"
        case .vision: return "vision"
        default: return "unknown"
        }
    }

    private static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }

    private static var instanceId: String {
        let stored = GatewaySettings.loadString(.instanceId, fallback: "")
        if !stored.isEmpty { return stored }
        let fresh = UUID().uuidString
        GatewaySettings.saveString(.instanceId, value: fresh)
        return fresh
    }
}

enum GatewaySettingsKey: String {
    case host = "gateway.host"
    case port = "gateway.port"
    case useTLS = "gateway.tls"
    case token = "gateway.token"
    case instanceId = "gateway.instanceId"
    case autoReconnect = "gateway.autoReconnect"
    case keepAlive = "gateway.keepAlive"
}

enum GatewaySettings {
    static let defaultHost = "127.0.0.1"
    static let defaultPort = 18789

    static func loadString(_ key: GatewaySettingsKey, fallback: String) -> String {
        UserDefaults.standard.string(forKey: key.rawValue) ?? fallback
    }

    static func loadBool(_ key: GatewaySettingsKey, fallback: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key.rawValue) == nil {
            return fallback
        }
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    static func saveString(_ key: GatewaySettingsKey, value: String) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }

    static func saveBool(_ key: GatewaySettingsKey, value: Bool) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
}

struct DeviceIdentity {
    let id: String
    let publicKey: Data
    let privateKey: Curve25519.Signing.PrivateKey
}

enum DeviceIdentityStore {
    private static let service = "ai.openclaw.gateway"
    private static let account = "deviceIdentity"

    static func loadOrCreate() -> DeviceIdentity {
        if let data = KeychainStore.loadData(service: service, account: account),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            return buildIdentity(from: key)
        }
        let key = Curve25519.Signing.PrivateKey()
        _ = KeychainStore.saveData(key.rawRepresentation, service: service, account: account)
        return buildIdentity(from: key)
    }

    private static func buildIdentity(from key: Curve25519.Signing.PrivateKey) -> DeviceIdentity {
        let publicKeyData = key.publicKey.rawRepresentation
        let id = sha256Hex(publicKeyData)
        return DeviceIdentity(id: id, publicKey: publicKeyData, privateKey: key)
    }

    static func reset() {
        _ = KeychainStore.delete(service: service, account: account)
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum DeviceSignatureVersion {
    case v2
    case v3
}

enum DeviceIdentitySigner {
    static func sign(identity: DeviceIdentity,
                     nonce: String,
                     timestampMs: Int,
                     clientId: String,
                     clientMode: String,
                     platform: String,
                     deviceFamily: String,
                     role: String,
                     scopes: [String],
                     token: String,
                     version: DeviceSignatureVersion) -> [String: Any] {
        let payload: String
        switch version {
        case .v2:
            payload = [
                "v2",
                identity.id,
                clientId,
                clientMode,
                role,
                scopes.joined(separator: ","),
                String(timestampMs),
                token,
                nonce
            ].joined(separator: "|")
        case .v3:
            let normalizedPlatform = normalizeDeviceMetadataForAuth(platform)
            let normalizedDeviceFamily = normalizeDeviceMetadataForAuth(deviceFamily)
            payload = [
                "v3",
                identity.id,
                clientId,
                clientMode,
                role,
                scopes.joined(separator: ","),
                String(timestampMs),
                token,
                nonce,
                normalizedPlatform,
                normalizedDeviceFamily
            ].joined(separator: "|")
        }

        let signature = try? identity.privateKey.signature(for: Data(payload.utf8))
        let signatureB64 = signature.map { base64URL($0) } ?? ""

        return [
            "id": identity.id,
            "publicKey": base64URL(identity.publicKey),
            "signature": signatureB64,
            "signedAt": timestampMs,
            "nonce": nonce
        ]
    }

    private static func base64URL(_ data: Data) -> String {
        var base = data.base64EncodedString()
        base = base.replacingOccurrences(of: "+", with: "-")
        base = base.replacingOccurrences(of: "/", with: "_")
        base = base.replacingOccurrences(of: "=", with: "")
        return base
    }

    private static func normalizeDeviceMetadataForAuth(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return toLowerASCII(trimmed)
    }

    private static func toLowerASCII(_ value: String) -> String {
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(value.unicodeScalars.count)
        for scalar in value.unicodeScalars {
            let v = scalar.value
            if v >= 65 && v <= 90 { // A-Z
                scalars.append(UnicodeScalar(v + 32)!)
            } else {
                scalars.append(scalar)
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

actor PendingResponseStore {
    private var map: [String: CheckedContinuation<[String: Any], Error>] = [:]

    func insert(id: String, continuation: CheckedContinuation<[String: Any], Error>) {
        map[id] = continuation
    }

    func take(id: String) -> CheckedContinuation<[String: Any], Error>? {
        map.removeValue(forKey: id)
    }

    func removeAll() {
        map.removeAll()
    }
}

struct GatewayError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum KeychainStore {
    @discardableResult
    static func saveString(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, service: service, account: account)
    }

    static func loadString(service: String, account: String) -> String? {
        guard let data = loadData(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveData(_ data: Data, service: String, account: String) -> Bool {
        delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadData(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
