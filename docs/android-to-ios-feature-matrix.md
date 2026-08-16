# Android → iOS Feature Matrix (Initial)

| Android Capability | iOS Implementation | Parity | Risk/Gap | Dependency |
|---|---|---|---|---|
| WebView host and URL loading | `WKWebView` in `WebViewWrapper` | Full (initial) | None | WebKit |
| Navigation (back/forward/reload) | `WebViewStore` commands | Full (initial) | None | SwiftUI + WebKit |
| Loading progress | `estimatedProgress` observer | Full (initial) | None | WebKit KVO |
| Pull to refresh | `UIRefreshControl` on scroll view | Full (initial) | None | UIKit |
| JS-native bridge | `window.NativeBridge` + `WKScriptMessageHandler` | Partial | Contract expansion needed | WebKit |
| Bridge command allowlist | `WebWrapperConfig.allowedBridgeCommands` | Full (initial) | None | Config |
| Origin restriction | `allowedBridgeOrigins` host validation | Partial | Should be upgraded to full origin tuple | Config |
| Domain navigation policy | allow/block host checks | Partial | Regex/subdomain policy not added | Config |
| Device info API | `device_info` command | Full (initial) | Expand hardware attrs later | UIKit |
| Local storage API | user defaults storage bridge | Partial | Encryption strategy not implemented | Foundation |
| External link intent | `UIApplication.open` | Full (initial) | scheme policy can be stricter | UIKit |
| Share intent | `UIActivityViewController` | Full (initial) | None | UIKit |
| Runtime permissions | camera/mic/photos/location | Partial | no proactive UX prompts flow | AVFoundation/Photos/CoreLocation |
| Download handling | `WKDownloadDelegate` with temp destination | Partial | file manager/open-in flow pending | WebKit |
| Lifecycle bridge events | active/background events | Full (initial) | None | UIKit notifications |
| Network status events | `NWPathMonitor` event + reload | Partial | offline cache strategy pending | Network |
| Deep links | `onOpenURL` load | Partial | route parsing/state hydration pending | SwiftUI |
| Cookie/session modes | persistent vs non-persistent store | Partial | explicit cookie sync strategy pending | WebKit |
| File upload chooser | Not implemented yet | Not implemented | Required for parity | WKUIDelegate + pickers |
| Push notifications | Not implemented yet | Not implemented | Required for parity | UserNotifications |
