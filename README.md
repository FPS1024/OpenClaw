# OpenClaw

OpenClaw is a lightweight iOS client for the OpenClaw gateway, offering real-time chat with WebSocket connectivity and a clean SwiftUI interface.

**Features**
- WebSocket gateway connection
- Device pairing and secure signatures
- Auto reconnect and keep-alive ping
- Streaming responses with interrupt (pause)
- Markdown rendering for assistant messages
- Chat history sync on reconnect (with local cache fallback)

**Requirements**
- Xcode 15+
- iOS 16+
- An OpenClaw gateway you can reach on your network or over the internet

**Setup**
1. Open the project in Xcode.
2. Run the app on a device or simulator.
3. Go to `Settings` → `Gateway` and set Host, Port, Token, and TLS if needed.
4. Tap `Connect`.

**Pairing**
If the gateway reports `pairing required`, approve the pending device on the gateway server.

Example:
```bash
openclaw devices list
openclaw devices approve <request-id>
```

**Usage**
- Send a message from the chat tab.
- When the assistant is streaming, the send button turns into a pause button so you can interrupt.
- If you leave and return to the app, it will reconnect automatically if enabled in `Remote`.

**Local Network Permission**
On first launch, iOS may ask for local network permission. Accepting it allows the app to connect to a gateway on your LAN.

**License**
MIT (planned). You can keep author credits in the About page and README.

**Acknowledgements**
The name and icon belong to the OpenClaw community and its official repository owners.
