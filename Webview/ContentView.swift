import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @StateObject private var store = WebViewStore()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var previousNetworkConnected: Bool?

    private let config = WebWrapperConfig(
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

    var body: some View {
        VStack(spacing: 0) {
            if store.isLoading {
                ProgressView(value: store.estimatedProgress)
                    .progressViewStyle(.linear)
            }

            WebViewWrapper(store: store, config: config)

            if let errorMessage = store.errorMessage {
                VStack(spacing: 8) {
                    Text("Failed to load page")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        store.send(.reload)
                    }
                }
                .padding()
            }

            HStack {
                Button("Back") {
                    store.send(.goBack)
                }
                .disabled(!store.canGoBack)

                Button("Forward") {
                    store.send(.goForward)
                }
                .disabled(!store.canGoForward)

                Button("Reload") {
                    store.send(.reload)
                }
            }
            .buttonStyle(.bordered)
            .padding(.vertical, 8)
        }
        .onOpenURL { url in
            store.send(.load(url))
        }
        .onReceive(networkMonitor.$isConnected.removeDuplicates()) { isConnected in
            store.send(.emitEvent(name: "network_status", payload: ["connected": isConnected ? "true" : "false"]))
            if let previous = previousNetworkConnected, !previous, isConnected {
                store.send(.reload)
            }
            previousNetworkConnected = isConnected
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            store.send(.emitEvent(name: "app_lifecycle", payload: ["state": "active"]))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            store.send(.emitEvent(name: "app_lifecycle", payload: ["state": "background"]))
        }
    }
}

#Preview {
    ContentView()
}
