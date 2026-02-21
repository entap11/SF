# VS Handshake Backend Contract

This contract matches the client transport in `scripts/state/vs_handshake_state.gd` and `scripts/state/vs_handshake_transport_http.gd`.

## Transport

- Base URL: configured via `SF_VS_BACKEND_URL` (or project setting `swarmfront/vs/backend_url`).
- Auth token: optional bearer token from `SF_VS_BACKEND_TOKEN` (or `swarmfront/vs/backend_token`).
- Method: `POST`
- Content-Type: `application/json`
- Route shape: `POST <base_url>/<action>`

Example:
- `POST https://your-backend.example/v1/create_invite`
- `POST https://your-backend.example/v1/publish_intent`

## Envelope Rules

- Request body is the action payload dictionary.
- Response body must be JSON object.
- Recommended response shape:
  - Success: `{ "ok": true, ... }`
  - Failure: `{ "ok": false, "err": "reason_code", ... }`
- If `ok` is omitted, client treats response as success by default.

## Actions

### `create_invite`
Request:
```json
{
  "profile": { "uid": "u1", "display_name": "Host" },
  "context": { "mode": "PVP", "map_count": 1, "price_usd": 0, "free_roll": true }
}
```
Response:
```json
{
  "ok": true,
  "session_id": "S12345678",
  "invite_code": "VS12345",
  "session": { "...": "session object" }
}
```

### `join_invite`
Request:
```json
{
  "invite_code": "VS12345",
  "profile": { "uid": "u2", "display_name": "Guest" }
}
```
Response:
```json
{
  "ok": true,
  "session_id": "S12345678",
  "session": { "...": "session object" }
}
```

### `enqueue_quick_match`
Request:
```json
{
  "profile": { "uid": "u1", "display_name": "Host" },
  "context": { "mode": "PVP", "map_count": 1, "price_usd": 0, "free_roll": true }
}
```
Response (queued):
```json
{ "ok": true, "matched": false, "ticket_id": "Q12345678" }
```
Response (matched):
```json
{ "ok": true, "matched": true, "session_id": "S12345678", "session": { "...": "session object" } }
```

### `poll_quick_match`
Request:
```json
{ "ticket_id": "Q12345678" }
```
Response:
```json
{ "ok": true, "matched": false, "ticket_id": "Q12345678" }
```
or
```json
{ "ok": true, "matched": true, "session_id": "S12345678", "session": { "...": "session object" } }
```

### `cancel_quick_match`
Request:
```json
{ "ticket_id": "Q12345678", "uid": "u1" }
```
Response:
```json
{ "ok": true }
```

### `get_session`
Request:
```json
{ "session_id": "S12345678" }
```
Response (preferred):
```json
{ "ok": true, "session": { "...": "session object" } }
```
Also accepted by client:
- raw session object as top-level JSON dictionary.

### `set_ready`
Request:
```json
{ "session_id": "S12345678", "uid": "u1", "ready": true }
```
Response:
```json
{ "ok": true, "session": { "...": "session object" } }
```

### `can_start`
Request:
```json
{ "session_id": "S12345678", "uid": "u1" }
```
Response:
```json
{ "ok": true, "can_start": true }
```

### `start_session`
Request:
```json
{ "session_id": "S12345678", "uid": "u1" }
```
Response:
```json
{ "ok": true, "session": { "...": "session object" } }
```

### `leave_session`
Request:
```json
{ "session_id": "S12345678", "uid": "u1" }
```
Response:
```json
{ "ok": true, "closed": true }
```
or
```json
{ "ok": true, "closed": false, "session": { "...": "session object" } }
```

### `publish_intent`
Request:
```json
{
  "session_id": "S12345678",
  "uid": "u1",
  "command": {
    "kind": "lane_intent",
    "src": 11,
    "dst": 22,
    "intent": "attack",
    "src_owner": 1,
    "dst_owner": 2,
    "issued_ms": 123456789
  }
}
```
Response:
```json
{ "ok": true, "seq": 42 }
```

### `poll_intents`
Request:
```json
{ "session_id": "S12345678", "uid": "u2", "after_seq": 41 }
```
Response:
```json
{
  "ok": true,
  "latest_seq": 42,
  "events": [
    {
      "seq": 42,
      "uid": "u1",
      "ts_unix": 1739980800,
      "command": { "kind": "lane_intent", "src": 11, "dst": 22, "intent": "attack" }
    }
  ]
}
```

## Session Object (minimum fields expected by client)

```json
{
  "id": "S12345678",
  "invite_code": "VS12345",
  "source": "invite",
  "status": "waiting",
  "created_unix": 1739980800,
  "expires_unix": 1739981700,
  "host": { "uid": "u1", "display_name": "Host", "ready": false },
  "guest": { "uid": "u2", "display_name": "Guest", "ready": false },
  "context": { "mode": "PVP", "map_count": 1, "price_usd": 0, "free_roll": true }
}
```

## Error Codes (recommended)

- `invalid_args`
- `invalid_profile`
- `session_not_found`
- `invite_not_found`
- `invite_full`
- `ticket_not_found`
- `player_not_in_session`
- `not_ready_or_not_host`

## Fallback Behavior

If transport fails at HTTP/network/parsing level, client falls back to local in-memory handshake state.
Application-level errors (`ok=false`) do not trigger fallback.
