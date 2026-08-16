import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers

struct WebViewWrapper: UIViewRepresentable {
    @ObservedObject var store: WebViewStore
    let config: WebWrapperConfig

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, config: config)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: config.makeWebConfiguration())
        context.coordinator.attach(webView: webView)

        if let userAgent = config.customUserAgent {
            webView.customUserAgent = userAgent
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshPulled), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        let request = URLRequest(url: config.initialURL)
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.handlePendingCommandIfNeeded(webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKDownloadDelegate, UIDocumentPickerDelegate {
        private let store: WebViewStore
        private let config: WebWrapperConfig
        private let storage = WebWrapperStorage()
        private let permissionManager = PermissionManager()

        private weak var webView: WKWebView?
        private var handledCommandVersion: Int = 0
        private var filePickerCompletion: (([URL]?) -> Void)?

        init(store: WebViewStore, config: WebWrapperConfig) {
            self.store = store
            self.config = config
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.configuration.userContentController.add(self, name: config.bridgeName)
            injectBridgeScript(into: webView)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: config.bridgeName)
            webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        }

        @objc func refreshPulled() {
            webView?.reload()
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == #keyPath(WKWebView.estimatedProgress), let webView else { return }
            Task { @MainActor in
                store.updateNavigationState(
                    currentURL: webView.url,
                    canGoBack: webView.canGoBack,
                    canGoForward: webView.canGoForward,
                    progress: webView.estimatedProgress,
                    isLoading: webView.isLoading
                )
            }
        }

        func handlePendingCommandIfNeeded(_ webView: WKWebView) {
            guard store.commandVersion > handledCommandVersion else { return }
            let currentVersion = store.commandVersion
            let commands = store.dequeuePendingCommands()
            handledCommandVersion = currentVersion
            for command in commands {
                switch command {
                case let .load(url):
                    webView.load(URLRequest(url: url))
                case .goBack:
                    if webView.canGoBack { webView.goBack() }
                case .goForward:
                    if webView.canGoForward { webView.goForward() }
                case .reload:
                    webView.reload()
                case let .emitEvent(name, payload):
                    emitEventToWeb(name: name, payload: payload)
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                store.errorMessage = nil
                store.updateNavigationState(
                    currentURL: webView.url,
                    canGoBack: webView.canGoBack,
                    canGoForward: webView.canGoForward,
                    progress: webView.estimatedProgress,
                    isLoading: true
                )
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
            Task { @MainActor in
                store.updateNavigationState(
                    currentURL: webView.url,
                    canGoBack: webView.canGoBack,
                    canGoForward: webView.canGoForward,
                    progress: webView.estimatedProgress,
                    isLoading: false
                )
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error)
        }

        private func handleNavigationError(_ error: Error) {
            webView?.scrollView.refreshControl?.endRefreshing()
            Task { @MainActor in
                store.errorMessage = error.localizedDescription
                store.isLoading = false
            }
            WebWrapperLogger.error("Navigation error: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let host = navigationAction.request.url?.host
            guard config.isHostAllowed(host) else {
                decisionHandler(.cancel)
                WebWrapperLogger.warning("Blocked navigation host: \(host ?? "unknown")")
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if #available(iOS 14.5, *), !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            guard let presenter = topViewController() else {
                completionHandler(nil)
                return
            }

            filePickerCompletion = completionHandler
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data], asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = parameters.allowsMultipleSelection
            presenter.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            filePickerCompletion?(urls)
            filePickerCompletion = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            filePickerCompletion?(nil)
            filePickerCompletion = nil
        }

        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        @available(iOS 14.5, *)
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
            completionHandler(destination)
            WebWrapperLogger.info("Download destination: \(destination.path)")
        }

        @available(iOS 14.5, *)
        func downloadDidFinish(_ download: WKDownload) {
            emitEventToWeb(name: "download_complete", payload: ["status": "success"])
        }

        @available(iOS 14.5, *)
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            emitEventToWeb(name: "download_complete", payload: ["status": "failed", "error": error.localizedDescription])
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == config.bridgeName else { return }
            guard let body = message.body as? String, let data = body.data(using: .utf8) else {
                WebWrapperLogger.warning("Bridge message ignored: invalid body")
                return
            }

            do {
                let request = try JSONDecoder().decode(BridgeRequest.self, from: data)
                guard config.allowedBridgeCommands.contains(request.command) else {
                    sendBridgeResponse(BridgeResponse(id: request.id, success: false, result: nil, error: "Command not allowed"))
                    return
                }

                let origin = message.frameInfo.request.url?.host
                guard config.isOriginAllowed(origin) else {
                    sendBridgeResponse(BridgeResponse(id: request.id, success: false, result: nil, error: "Origin not allowed"))
                    return
                }

                Task {
                    let response = await handleBridgeRequest(request)
                    sendBridgeResponse(response)
                }
            } catch {
                WebWrapperLogger.error("Bridge decode failure: \(error.localizedDescription)")
            }
        }

        private func handleBridgeRequest(_ request: BridgeRequest) async -> BridgeResponse {
            switch request.command {
            case .deviceInfo:
                return BridgeResponse(
                    id: request.id,
                    success: true,
                    result: [
                        "platform": "iOS",
                        "systemVersion": UIDevice.current.systemVersion,
                        "model": UIDevice.current.model
                    ],
                    error: nil
                )
            case .openExternal:
                guard let urlString = request.payload?["url"], let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Invalid URL")
                }
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
                return BridgeResponse(id: request.id, success: true, result: ["opened": "true"], error: nil)
            case .share:
                guard let text = request.payload?["text"] else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Missing text")
                }
                await MainActor.run {
                    let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                    topViewController()?.present(vc, animated: true)
                }
                return BridgeResponse(id: request.id, success: true, result: ["shared": "true"], error: nil)
            case .storageSet:
                guard let key = request.payload?["key"], let value = request.payload?["value"] else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Missing key/value")
                }
                storage.set(value, forKey: key)
                return BridgeResponse(id: request.id, success: true, result: ["stored": "true"], error: nil)
            case .storageGet:
                guard let key = request.payload?["key"] else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Missing key")
                }
                guard let value = storage.get(forKey: key) else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Key not found")
                }
                return BridgeResponse(id: request.id, success: true, result: ["value": value], error: nil)
            case .storageRemove:
                guard let key = request.payload?["key"] else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Missing key")
                }
                storage.remove(forKey: key)
                return BridgeResponse(id: request.id, success: true, result: ["removed": "true"], error: nil)
            case .navigateBack:
                await MainActor.run { [weak self] in self?.webView?.goBack() }
                return BridgeResponse(id: request.id, success: true, result: nil, error: nil)
            case .navigateForward:
                await MainActor.run { [weak self] in self?.webView?.goForward() }
                return BridgeResponse(id: request.id, success: true, result: nil, error: nil)
            case .reload:
                await MainActor.run { [weak self] in self?.webView?.reload() }
                return BridgeResponse(id: request.id, success: true, result: nil, error: nil)
            case .requestPermission:
                guard let rawType = request.payload?["type"], let type = PermissionType(rawValue: rawType) else {
                    return BridgeResponse(id: request.id, success: false, result: nil, error: "Invalid permission type")
                }
                let status = await permissionManager.requestPermission(type)
                return BridgeResponse(id: request.id, success: true, result: ["status": status], error: nil)
            case .clearSession:
                await clearSessionData()
                return BridgeResponse(id: request.id, success: true, result: ["cleared": "true"], error: nil)
            }
        }

        private func clearSessionData() async {
            guard let webView else { return }
            let dataStore = webView.configuration.websiteDataStore
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            await withCheckedContinuation { continuation in
                dataStore.removeData(ofTypes: types, modifiedSince: .distantPast) {
                    continuation.resume()
                }
            }
            await MainActor.run {
                webView.reload()
            }
        }

        private func sendBridgeResponse(_ response: BridgeResponse) {
            do {
                let data = try JSONEncoder().encode(response)
                let base64 = data.base64EncodedString()
                let jsArgData = try JSONEncoder().encode(base64)
                guard let jsArg = String(data: jsArgData, encoding: .utf8) else { return }
                webView?.evaluateJavaScript("window.NativeBridge && window.NativeBridge._handleNativeResponseBase64(\(jsArg));")
            } catch {
                WebWrapperLogger.error("Bridge response encode failure: \(error.localizedDescription)")
            }
        }

        private func emitEventToWeb(name: String, payload: [String: String]) {
            let event = BridgeEvent(name: name, payload: payload)
            do {
                let data = try JSONEncoder().encode(event)
                let base64 = data.base64EncodedString()
                let jsArgData = try JSONEncoder().encode(base64)
                guard let jsArg = String(data: jsArgData, encoding: .utf8) else { return }
                webView?.evaluateJavaScript("window.NativeBridge && window.NativeBridge._handleNativeEventBase64(\(jsArg));")
            } catch {
                WebWrapperLogger.error("Bridge event encode failure: \(error.localizedDescription)")
            }
        }

        private func injectBridgeScript(into webView: WKWebView) {
            let source = """
            (function() {
              if (window.NativeBridge) { return; }
              const callbacks = {};
              const timeoutMs = 15000;

              function safeParse(value) {
                try { return JSON.parse(value); } catch { return null; }
              }

              function decodeBase64(value) {
                try { return atob(value); } catch { return null; }
              }

              window.NativeBridge = {
                call: function(command, payload) {
                  return new Promise(function(resolve, reject) {
                    const id = (globalThis.crypto && globalThis.crypto.randomUUID)
                      ? globalThis.crypto.randomUUID()
                      : Math.random().toString(36).substring(2);
                    callbacks[id] = { resolve: resolve, reject: reject };

                    setTimeout(function() {
                      if (callbacks[id]) {
                        callbacks[id].reject(new Error('Native timeout'));
                        delete callbacks[id];
                      }
                    }, timeoutMs);

                    const message = JSON.stringify({ id: id, command: command, payload: payload || {} });
                    window.webkit.messageHandlers.\(config.bridgeName).postMessage(message);
                  });
                },
                _handleNativeResponseBase64: function(rawBase64) {
                  const raw = decodeBase64(rawBase64);
                  if (!raw) { return; }
                  const response = safeParse(raw);
                  if (!response || !callbacks[response.id]) { return; }
                  if (response.success) {
                    callbacks[response.id].resolve(response.result || {});
                  } else {
                    callbacks[response.id].reject(new Error(response.error || 'Unknown native error'));
                  }
                  delete callbacks[response.id];
                },
                _handleNativeEventBase64: function(rawBase64) {
                  const raw = decodeBase64(rawBase64);
                  if (!raw) { return; }
                  const event = safeParse(raw);
                  if (!event) { return; }
                  window.dispatchEvent(new CustomEvent('nativeBridgeEvent', { detail: event }));
                }
              };
            })();
            """

            let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(script)
        }

        private func topViewController(base: UIViewController? = nil) -> UIViewController? {
            let resolvedBase: UIViewController?
            if let base {
                resolvedBase = base
            } else {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                if #available(iOS 15.0, *) {
                    resolvedBase = scenes.compactMap { $0.keyWindow }.first?.rootViewController
                } else {
                    resolvedBase = scenes
                        .flatMap { $0.windows }
                        .first(where: { $0.isKeyWindow })?
                        .rootViewController
                }
            }

            if let nav = resolvedBase as? UINavigationController {
                return topViewController(base: nav.visibleViewController)
            }
            if let tab = resolvedBase as? UITabBarController {
                return topViewController(base: tab.selectedViewController)
            }
            if let presented = resolvedBase?.presentedViewController {
                return topViewController(base: presented)
            }
            return resolvedBase
        }
    }
}
