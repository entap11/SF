# Rank Backend Contract

This contract matches client transport in:
- `scripts/state/rank_state.gd`
- `scripts/state/rank_transport_http.gd`
- Implemented by service scaffold in `tools/rank-service`

## Transport

- Base URL: `SF_RANK_BACKEND_URL` or project setting `swarmfront/rank/backend_url`
- Auth token: optional bearer token via `SF_RANK_BACKEND_TOKEN` or `swarmfront/rank/backend_token`
- Method: `POST`
- Content-Type: `application/json`
- Route shape: `POST <base_url>/<action>`
- Admin routes: authenticated `GET/POST /v1/admin/*`

Examples:
- `POST https://rank-backend.example/v1/get_snapshot`
- `POST https://rank-backend.example/v1/record_match_result`
- `POST http://127.0.0.1:8790/v1/rank/get_snapshot` (with `SF_RANK_BACKEND_URL=http://127.0.0.1:8790/v1/rank`)

## Envelope

- Request body is action payload JSON.
- Response body must be JSON object.
- Success shape: `{ "ok": true, ... }`
- Failure shape: `{ "ok": false, "err": "reason_code", ... }`
- If `ok` is omitted, client treats the response as success.

## State Payload (recommended)

Client hydrates local cache from any of:
- top-level payload containing `players_by_id`
- `snapshot` object with `players_by_id`
- `state` object with `players_by_id`

Recommended full state shape:
```json
{
  "local_player_id": "u_123",
  "players_by_id": {
    "u_123": {
      "player_id": "u_123",
      "display_name": "Player 123",
      "region": "GLOBAL",
      "wax_score": 100.0,
      "last_active_unix": 1739980800,
      "last_decay_day": 20000,
      "tier_id": "DRONE",
      "color_id": "GREEN",
      "rank_position": 1,
      "percentile": 1.0,
      "promotion_history": {"DRONE": true},
      "friends": [],
      "apex_active": false
    }
  }
}
```

## Actions

## Canonical Player IDs

- Beta/staging backend should use stable profile IDs in the shape `u_<12 hex chars>`.
- Bot seats may use `bot_<6 digits>`.
- When canonical ID enforcement is enabled on the service, rank-changing writes with any other ID shape are rejected.

### `get_snapshot`
Request:
```json
{ "local_player_id": "u_123" }
```
Response:
```json
{ "ok": true, "snapshot": { "...state payload..." } }
```

### `register_player`
Request:
```json
{
  "player_id": "u_123",
  "display_name": "Player 123",
  "region": "GLOBAL",
  "friends": []
}
```
Response (any of):
```json
{ "ok": true, "player": { "...player snapshot..." } }
```
or
```json
{ "ok": true, "snapshot": { "...state payload..." } }
```

### `set_player_friends`
Request:
```json
{ "player_id": "u_123", "friends": ["u_456"] }
```
Response:
```json
{ "ok": true }
```

### `set_player_region`
Request:
```json
{ "player_id": "u_123", "region": "NA" }
```
Response:
```json
{ "ok": true }
```

### `record_match_result`
Request:
```json
{
  "player_id": "u_123",
  "opponent_id": "u_456",
  "did_player_win": true,
  "mode_name": "STANDARD",
  "metadata": { "event_id": "evt_abc123" }
}
```
Response:
```json
{
  "ok": true,
  "player": { "...player snapshot..." },
  "opponent": { "...player snapshot..." }
}
```

### `apply_decay_tick`
Request:
```json
{}
```
Response:
```json
{ "ok": true, "players_decayed": 17 }
```

### `get_player_snapshot`
Request:
```json
{ "player_id": "u_123" }
```
Response:
```json
{ "ok": true, "player": { "...player snapshot..." } }
```

### `get_local_rank_view`
Request:
```json
{
  "requester_id": "u_123",
  "filter_name": "GLOBAL",
  "limit": 25
}
```
Response:
```json
{
  "ok": true,
  "board": {
    "filter": "GLOBAL",
    "rows": [],
    "local_context": {},
    "local_player_id": "u_123",
    "player": {}
  }
}
```

### `get_leaderboard_snapshot`
Request:
```json
{
  "requester_id": "u_123",
  "filter_name": "GLOBAL",
  "limit": 25
}
```
Response:
```json
{ "ok": true, "board": { "...same shape as local rank view..." } }
```

### `find_match_candidates`
Request:
```json
{
  "requester_id": "u_123",
  "queue_entries": [
    { "player_id": "u_456", "wait_seconds": 14.2 }
  ]
}
```
Response:
```json
{
  "ok": true,
  "rows": [
    {
      "player_id": "u_456",
      "display_name": "Player 456",
      "wax_score": 104.0,
      "wax_delta": 4.0,
      "tier_id": "DRONE",
      "color_id": "GREEN",
      "tier_distance": 0,
      "color_distance": 0,
      "wait_seconds": 14.2,
      "score": 9996.0
    }
  ]
}
```

### Debug (optional in non-prod)

- `debug_set_player_wax`
- `debug_set_last_active`

These are currently called by smoke/dev client flows.

## Idempotency (recommended)

For progression writes (`record_match_result`), include:
- `metadata.event_id` (unique per resolved match outcome)
- server-side dedupe by `(player_id, event_id)` or session-scoped key

## Fallback Behavior (client)

- Network/transport failure with backend configured: rank-changing writes fail closed with `reason=rank_backend_unavailable`.
- No configured backend: client can still run local-only rank state for smoke/dev flows.
- Application error (`ok=false`): client treats as handled and returns error upstream.

## Real-Time Expectation

- Rank-changing actions (especially `record_match_result`) must apply wax/tier/color/rank updates before the HTTP response is returned.
- No delayed reconciliation window for promotions/demotions.
- Demotion smoothing uses slot-based grace (default 5 pass-through positions), and full-tier overflow can bubble upward by promoting the top edge into adjacent higher tiers.

## Admin Endpoints

- `GET /health/details`
- `GET /v1/admin/players/:playerId`
- `GET /v1/admin/tier-counts`
- `GET /v1/admin/audit?limit=50&player_id=u_...&event_type=rank_state_changed`
- `POST /v1/admin/recompute`

All admin endpoints use the same bearer-token gate as the rank action route when `RANK_API_TOKEN` is configured.
