//
//  LocalNetworkPermissionRequester.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/20.
//

import Foundation
import Network

enum LocalNetworkPermissionRequester {
    static func request() async {
        await withCheckedContinuation { continuation in
            let browser = NWBrowser(for: .bonjour(type: "_openclaw._tcp", domain: nil), using: .udp)
            browser.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed:
                    browser.cancel()
                    continuation.resume()
                default:
                    break
                }
            }
            browser.browseResultsChangedHandler = { _, _ in }
            browser.start(queue: .main)
        }
    }
}

