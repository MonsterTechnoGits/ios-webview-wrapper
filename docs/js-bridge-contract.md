# JS Bridge Contract (v1)

## Entry Point
`window.NativeBridge.call(command, payload)` returns a Promise.

## Request Shape
```json
{ "id": "string", "command": "string", "payload": { "key": "value" } }
```

## Response Shape
```json
{ "id": "string", "success": true, "result": { "key": "value" }, "error": null }
```

## Event Shape
Native dispatches browser event `nativeBridgeEvent` with:
```json
{ "name": "string", "payload": { "key": "value" } }
```

## Supported Commands (v1)
- `device_info`
- `open_external` (`url`)
- `share` (`text`)
- `storage_set` (`key`, `value`)
- `storage_get` (`key`)
- `storage_remove` (`key`)
- `navigate_back`
- `navigate_forward`
- `reload`
- `request_permission` (`type`: `camera|microphone|photos|location`)
- `clear_session`

## Security Controls
- Command allowlist enforcement.
- Host/origin allowlist checks.
- Domain allow/block policy for navigation.
- Promise timeout in JS runtime.
