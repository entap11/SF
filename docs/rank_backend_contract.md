# ENTaP Identity / Rank Backend Contract

This contract matches client transport in:
- `scripts/state/rank_state.gd`
- `scripts/state/rank_transport_http.gd`
- Implemented by service scaffold in `tools/rank-service`

The folder name is historical. For Swarmfront beta, this service is the first
ENTaP platform identity authority. Rank features may remain dormant; beta
scope is account identity creation only.

## Transport

- Base URL: `SF_RANK_BACKEND_URL` or project setting `swarmfront/rank/backend_url`
- Auth token: optional bearer token via `SF_RANK_BACKEND_TOKEN` or `swarmfront/rank/backend_token`
- Method: `POST`
- Content-Type: `application/json`
- Route shape: `POST <base_url>/<action>`
- Admin routes: authenticated `GET/POST /v1/admin/*`

Examples:
- `POST https://rank-backend.example/v1/rank/register_player`
- `POST https://rank-backend.example/v1/rank/get_snapshot`
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
  "local_player_id": "018f0000-0000-7000-8000-000000000123",
  "players_by_id": {
    "018f0000-0000-7000-8000-000000000123": {
      "id": "018f0000-0000-7000-8000-000000000123",
      "player_id": "018f0000-0000-7000-8000-000000000123",
      "entap_id": "AAA 000",
      "call_sign": "Player_0000",
      "display_name": "Player_0000",
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

- Beta/staging backend uses server-assigned UUIDv7 account IDs.
- The client must not generate or send authoritative IDs during first account creation.
- `entap_id` is server-assigned, public, permanent, unique, and matches `^[A-Z]{3} [0-9]{3}$`.
- `call_sign` is player-chosen, public, and unique case-insensitively.
- Bot seats may use `bot_<6 digits>`.
- When canonical ID enforcement is enabled on the service, rank-changing writes with any other ID shape are rejected.

### `get_snapshot`
Request:
```json
{ "local_player_id": "018f0000-0000-7000-8000-000000000123" }
```
Response:
```json
{ "ok": true, "snapshot": { "...state payload..." } }
```

### `register_player`
Request:
```json
{
  "call_sign": "Player_0000",
  "region": "NA",
  "install_metadata": {
    "client": "swarmfront",
    "platform": "iOS"
  }
}
```
Response:
```json
{
  "ok": true,
  "player": {
    "id": "018f0000-0000-7000-8000-000000000123",
    "player_id": "018f0000-0000-7000-8000-000000000123",
    "entap_id": "AAA 000",
    "call_sign": "Player_0000",
    "display_name": "Player_0000"
  }
}
```
Duplicate call sign response:
```json
{
  "ok": false,
  "err": "call_sign_not_unique",
  "call_sign": "Player_0000"
}
```

### `set_player_friends`
Request:
```json
{ "player_id": "018f0000-0000-7000-8000-000000000123", "friends": ["018f0000-0000-7000-8000-000000000456"] }
```
Response:
```json
{ "ok": true }
```

### `set_player_region`
Request:
```json
{ "player_id": "018f0000-0000-7000-8000-000000000123", "region": "NA" }
```
Response:
```json
{ "ok": true }
```

### `record_match_result`
Request:
```json
{
  "player_id": "018f0000-0000-7000-8000-000000000123",
  "opponent_id": "018f0000-0000-7000-8000-000000000456",
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

The legacy action above is not the public Standard 1v1 trust path. Public
settlement is server-to-server only:

### `POST /v1/service/settle-standard-1v1`

Requires a short-lived ES256 VS service JWT with `rank:settle` scope and the
exact configured issuer, audience, subject, and key ID. Request:

```json
{
  "rank_event_id": "01900000-0000-7000-8000-000000000123",
  "mode_id": "STANDARD_1V1",
  "signed_result": {
    "payload": { "result_id": "01900000-0000-7000-8000-000000000123" },
    "payload_hash": "<sha256 canonical JSON>",
    "key_id": "authority-key-v1",
    "algorithm": "ES256",
    "signature": "<base64url P-256 signature>"
  }
}
```

Rank independently verifies the authority receipt and its Standard 1v1 ordered
placements. `rank_event_id` must equal `result_id`; retries return the existing
settlement and cannot apply a second mutation. This route requires both
`RANK_VERIFIED_MATCH_MUTATIONS_ENABLED=true` and the separate economy-mutation
gate. Both default false.

### `GET /v1/public/leaderboard/global?limit=25`

Requires `RANK_PUBLIC_LEADERBOARDS_ENABLED=true`, which defaults false. The board
is shared PostgreSQL-backed Rank data and includes `generated_at`,
`cache_age_seconds`, `stale`, and `source`. Public clients must not substitute a
device-local board when this endpoint is unavailable.

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
{ "player_id": "018f0000-0000-7000-8000-000000000123" }
```
Response:
```json
{ "ok": true, "player": { "...player snapshot..." } }
```

### `get_local_rank_view`
Request:
```json
{
  "requester_id": "018f0000-0000-7000-8000-000000000123",
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
    "local_player_id": "018f0000-0000-7000-8000-000000000123",
    "player": {}
  }
}
```

### `get_leaderboard_snapshot`
Request:
```json
{
  "requester_id": "018f0000-0000-7000-8000-000000000123",
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
  "requester_id": "018f0000-0000-7000-8000-000000000123",
  "queue_entries": [
    { "player_id": "018f0000-0000-7000-8000-000000000456", "wait_seconds": 14.2 }
  ]
}
```
Response:
```json
{
  "ok": true,
  "rows": [
    {
      "player_id": "018f0000-0000-7000-8000-000000000456",
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
- `GET /v1/admin/audit?limit=50&player_id=018f0000-0000-7000-8000-000000000123&event_type=rank_state_changed`
- `POST /v1/admin/recompute`

All admin endpoints use the same bearer-token gate as the rank action route when `RANK_API_TOKEN` is configured.

## Database Migration

Run migrations before pointing a beta build at the service:
```bash
cd tools/rank-service
DATABASE_URL="$DATABASE_URL" npm run migrate
```

Identity requirements enforced by migrations:
- `rank_players.id UUID PRIMARY KEY`
- `rank_players.entap_id TEXT NOT NULL UNIQUE`
- `rank_players.call_sign TEXT NOT NULL`
- `chk_rank_players_entap_id_format`
- `uq_rank_players_call_sign_lower`
- `rank_entap_id_seq`
- `rank_uuid_v7()`
- `rank_entap_id_from_sequence(seq bigint)`

ENTaP IDs are allocated inside the account insert transaction with:
```sql
rank_entap_id_from_sequence(nextval('rank_entap_id_seq'))
```

Sequence gaps are acceptable. Duplicate ENTaP IDs are not acceptable and remain guarded by `UNIQUE(entap_id)`.

## Environment Variables

Service:
- `DATABASE_URL`: required Postgres connection string.
- `PORT`: Render supplies this automatically.
- `BIND_HOST`: use `0.0.0.0` on Render.
- `RANK_API_TOKEN`: optional in local development and required in production.
- `RANK_ECONOMY_MUTATIONS_ENABLED`: defaults to `false`; keep false during Security Sprint 0.
- `RANK_ECONOMY_RESET_ENABLED`: defaults to `false`; the epoch reset also requires the mutation gate.
- `RANK_ECONOMY_EPOCH`: stored epoch marker; it does not trigger a reset by itself.
- `RANK_ENFORCE_CANONICAL_PLAYER_IDS`: keep `true`.
- `RANK_ENABLE_DEBUG_ACTIONS`: keep `false` for beta/staging/prod unless explicitly testing.
- `RANK_DEFAULT_REGION`: default `GLOBAL`.

Client:
- `SF_RANK_BACKEND_URL`: preferred runtime override for dev/staging.
- `SF_RANK_BACKEND_TOKEN`: trusted-runtime bearer token matching `RANK_API_TOKEN`; do not embed it in a public export.
- `swarmfront/rank/backend_url`: project/export setting fallback.
- `swarmfront/rank/backend_token`: project/export setting fallback.
- `swarmfront/rank/backend_timeout_sec`: request timeout.

Recommended URLs:
- Dev: `SF_RANK_BACKEND_URL=http://127.0.0.1:8790/v1/rank`
- Staging: `SF_RANK_BACKEND_URL=https://YOUR-RANK-STAGING.onrender.com/v1/rank`
- Production: `SF_RANK_BACKEND_URL=https://YOUR-RANK-PROD.onrender.com/v1/rank`

## Render Deployment

Create a separate Render Web Service for `tools/rank-service`; do not reuse the VS backend.

Suggested settings:
- Root directory: `tools/rank-service`
- Runtime: Node
- Build command: `npm ci && npm run build`
- Start command: `npm run start`
- Health check path: `/health`
- Environment:
  - `DATABASE_URL`
  - `BIND_HOST=0.0.0.0`
  - `RANK_API_TOKEN=<staging-or-prod-secret>`
  - `RANK_ENFORCE_CANONICAL_PLAYER_IDS=true`
  - `RANK_ENABLE_DEBUG_ACTIONS=false`
  - `RANK_ECONOMY_MUTATIONS_ENABLED=false`
  - `RANK_ECONOMY_RESET_ENABLED=false`

After first deploy, run migrations from a trusted shell:
```bash
cd tools/rank-service
DATABASE_URL="postgres://..." npm run migrate
```

## Staging Smoke

One clean staging smoke command:
```bash
cd tools/rank-service
RANK_SMOKE_BASE_URL="https://YOUR-RANK-STAGING.onrender.com/v1/rank" \
RANK_SMOKE_TOKEN="$RANK_API_TOKEN" \
SF_ALLOW_LIVE_BACKEND_TESTS=1 \
npm run smoke:identity
```

The smoke verifies:
- service health
- account creation
- UUIDv7 `id`
- `AAA 000` ENTaP ID format
- duplicate call sign returns `call_sign_not_unique`
- rapid account creations do not share an ENTaP ID

## Quarantine persistence boundary

- Rank store writes require an explicit `identity` or `economy` classification. Missing classification fails before a database connection is acquired.
- `economy` covers match and contest results, decay, recomputation, Wax/rank-derived values, processed events, economy audits, and economy epoch/reset state. It is blocked by `RANK_ECONOMY_MUTATIONS_ENABLED=false`.
- `identity` permits only local identity selection, friend changes, and region changes with their narrowly scoped non-economy audits. The store compares protected fields before persistence and rejects classification misuse.
- Registration is the explicit quarantine exception: it creates only the identity, a zero-Wax starter row, and one `player_registered` audit record.
- Automated client smoke tests reject non-loopback backends before network activity unless `SF_ALLOW_LIVE_BACKEND_TESTS=1` is set deliberately.
