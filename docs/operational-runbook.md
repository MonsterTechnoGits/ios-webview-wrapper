# Operational Runbook

## Configuration
- Edit `WebWrapperConfig` in `ContentView` (or inject from environment/build settings).
- Set:
  - `initialURL`
  - `allowedHosts` / `blockedHosts`
  - `allowedBridgeOrigins`
  - `allowedBridgeCommands`
  - `isIncognito`, `customUserAgent`

## Release Readiness Checklist
- Verify URL/domain policy for production hosts.
- Validate bridge command surface against product requirements.
- Validate permissions flow (camera/mic/photos/location).
- Validate downloads and external intents.
- Validate deep links and state restoration behavior.
- Validate lifecycle and network event behavior.

## Troubleshooting
- Bridge failures: inspect app logs from `WebWrapperLogger`.
- Navigation blocked: check allow/block hosts in config.
- Permission denied: inspect iOS Settings and plist keys.
- Download issues: verify MIME behavior and destination path handling.

## Known Gaps (current state)
- No file upload picker implementation.
- No push notification module.
- No advanced cookie/token sync orchestration.
- No full route-based deep-link hydration model.
