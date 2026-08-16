# iOS WebView Wrapper Architecture

## Modules
- **Core Engine**: `WebViewWrapper` + `WebViewStore` for loading, navigation state, progress, errors, pull-to-refresh.
- **Bridge Layer**: `BridgeModels` and in-wrapper bridge runtime (`window.NativeBridge`) with request/response/event protocol.
- **Policy Layer**: `WebWrapperConfig` host allow/block rules, JS toggle, origin/command allowlist.
- **Capabilities**:
  - Device info
  - External URL open
  - Share sheet
  - Key/value storage
  - Permission request (camera, mic, photos, location)
  - Download lifecycle events
- **Observability**: `WebWrapperLogger` for structured app-side logging.
- **Runtime Context**: `NetworkMonitor` and lifecycle events bridged to web.

## Data Flow
1. SwiftUI view sends command to `WebViewStore`.
2. `WebViewWrapper.Coordinator` executes command on `WKWebView`.
3. Web calls `window.NativeBridge.call(...)`.
4. iOS handler validates origin + command and returns structured response.
5. Native emits async events via `nativeBridgeEvent` in JS.

## Security Defaults
- Bridge origin policy is deny-by-default when no origins are configured.
- Bridge script is injected into the main frame only.
