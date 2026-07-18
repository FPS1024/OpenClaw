//
//  LocalNetworkPermissionRequester.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/20.
//

import Foundation
import Network

enum LocalNetworkPermissionRequester {
    static func request() {
        let browser = NWBrowser(for: .bonjour(type: "_openclaw._tcp", domain: nil), using: .udp)
        browser.stateUpdateHandler = { state in
            if case .ready = state {
                browser.cancel()
            } else if case .failed = state {
                browser.cancel()
            }
        }
        browser.browseResultsChangedHandler = { _, _ in }
        browser.start(queue: .main)

        // Permission prompting is best-effort and must never hold up a gateway connection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            browser.cancel()
        }
    }
}
