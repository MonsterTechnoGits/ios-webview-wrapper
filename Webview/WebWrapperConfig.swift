import Foundation
import WebKit

struct WebWrapperConfig {
    let initialURL: URL
    let allowedHosts: Set<String>
    let blockedHosts: Set<String>
    let customUserAgent: String?
    let isIncognito: Bool
    let javaScriptEnabled: Bool
    let allowsInlineMediaPlayback: Bool
    let bridgeName: String
    let allowedBridgeOrigins: Set<String>
    let allowedBridgeCommands: Set<BridgeCommand>

    static let `default` = WebWrapperConfig(
        initialURL: URL(string: "https://example.com")!,
        allowedHosts: [],
        blockedHosts: [],
        customUserAgent: nil,
        isIncognito: false,
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        bridgeName: "iosBridge",
        allowedBridgeOrigins: ["example.com"],
        allowedBridgeCommands: Set(BridgeCommand.allCases)
    )

    func makeWebConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled
        configuration.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        configuration.websiteDataStore = isIncognito ? .nonPersistent() : .default()
        return configuration
    }

    func isHostAllowed(_ host: String?) -> Bool {
        guard let host else { return false }
        if blockedHosts.contains(host) { return false }
        if allowedHosts.isEmpty { return true }
        return allowedHosts.contains(host)
    }

    func isOriginAllowed(_ origin: String?) -> Bool {
        guard let origin else { return false }
        if allowedBridgeOrigins.isEmpty { return false }
        return allowedBridgeOrigins.contains(origin)
    }
}
