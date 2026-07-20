# VS Handshake Backend Contract

This contract matches the client transport in `scripts/state/vs_handshake_state.gd` and `scripts/state/vs_handshake_transport_http.gd`.

Paid VS sessions must also satisfy the authoritative escrow and settlement rules in `docs/money_game_ledger_contract.md`.

Async paid contests must also satisfy the scheduled contest lifecycle in `docs/money_game_ledger_contract.md`:

```text
OPEN -> CLOSED -> PAYOUT_PENDING -> PAYOUT_APPROVED
```

The VS backend owns money movement. Client state may mirror contest status for menu/ops UX, but posted escrow, payout, refund, and rake transactions are backend-authoritative.

## Transport

- Base URL: configured via `SF_VS_BACKEND_URL` (or project setting `swarmfront/vs/backend_url`).
- Client auth token: optional bearer token from `SF_VS_BACKEND_TOKEN` (or `swarmfront/vs/backend_token`). Security Sprint 0 keeps the exported project setting empty. This is never the match-authority or admin secret.
- Method: `POST`
- Content-Type: `application/json`
- Route shape: `POST <base_url>/<action>`

## Security Sprint 0 route policy

`VS_ECONOMY_MUTATIONS_ENABLED` defaults to false. While false, all quarantined actions return HTTP 503 with this stable body:

```json
{ "ok": false, "err": "economy_disabled", "code": "economy_disabled" }
```

Quarantined actions are:

- Money: `open_money_escrow`, `settle_money_match`, `refund_money_match`.
- Async contests: `open_async_entry_escrow`, `submit_async_contest_result`, `preview_async_contest_result_payout_report`, `preview_async_contest_payout_report`, `approve_async_contest_payout_report`, `settle_async_contest`, `settle_async_contest_payouts`, `settle_async_contest_payout_percentages`, `refund_async_entry`.
- Honey: `record_honey_activity`, `grant_honey`, `debit_honey`, `debit_hive_honey_purchase`, `debug_set_honey_balance`.
- Crucible/Wax: `preview_crucible_entry`, `update_crucible_config`, `open_crucible_escrow`, `settle_crucible_match`, `refund_crucible_match`, `resolve_crucible_review`, `record_crucible_lifecycle`, `record_competitive_wax_result`, `award_crucible_wax`, `debug_set_crucible_balance`.

Public Crucible uses the durable `CRUCIBLE_1V1` roster and separate PostgreSQL
settlement actions: `open_public_crucible_escrow` and
`settle_public_crucible_verified` require match authority;
`refund_public_crucible`, `reverse_public_crucible_settlement`,
`set_public_crucible_balance`, and `get_public_crucible_metrics` require ops.
The fixed accounting is 1,000 millis from each player, 1,800 to the verified
winner, and 200 to the non-client-addressable award reserve. Public mode and
Wax mutation flags are independent and default false.
- Contest dashboard: `POST /v1/contest_dash/config` and `POST /v1/contest_dash/delete`.

Paid or Crucible variants of `create_invite`, `join_invite`, `enqueue_quick_match`, `create_friend_invite`, `respond_friend_invite`, `start_session`, bot fill, and `leave_session` also fail closed. Their ordinary free variants remain available.

Read classification:

- Public policy/configuration: `get_honey_policy`, `get_crucible_config`, `get_wax_policy`, and `GET /v1/contest_dash/config`.
- Admin-only private economy data: `get_money_transactions`, `get_money_payout_summary`, `debug_get_money_ledger_snapshot`, `list_async_contest_results`, `list_async_contest_payout_reports`, `get_honey_balance`, `preview_hive_honey_purchase`, `get_honey_transactions`, `debug_get_honey_ledger_snapshot`, `debug_get_crucible_snapshot`, and `get_wax_audit_snapshot`.
- Public/client session traffic: free invite/queue/session/ready/start/leave, heartbeat/friends, intent exchange, and spectator use with a server-issued spectator grant.

Mutation authorization when the quarantine is eventually lifted:

- Match-authority-only actions use `VS_MATCH_AUTHORITY_TOKEN` on server-to-server requests. The token must never be distributed to Godot/TestFlight.
- Administrative mutations and all private economy reads use `VS_ADMIN_TOKEN` and the configured admin role.
- `debug_fill_quick_match` and `debug_fill_session` are admin-only. `fill_free_bot_match` is the narrow client operation for free, non-Crucible bot sessions.
- `create_spectator_grant` uses the independent `VS_SPECTATOR_ADMIN_TOKEN`; an empty or forged value never authorizes it, and the development bypass is ignored in production.

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

## Session roster contract (v2)

Every synchronized session response includes one canonical roster. `host` and
`guest` remain compatibility aliases for roster seats 1 and 2; new code must use
`roster`.

```json
{
  "contract_version": 2,
  "contract_hash": "64 lowercase hex characters",
  "required_players": 4,
  "roster": [
    { "uid": "u1", "display_name": "P1", "seat": 1, "role": "host", "team_id": 1, "ready": false },
    { "uid": "u2", "display_name": "P2", "seat": 2, "role": "player", "team_id": 2, "ready": false },
    { "uid": "u3", "display_name": "P3", "seat": 3, "role": "player", "team_id": 1, "ready": false },
    { "uid": "u4", "display_name": "P4", "seat": 4, "role": "player", "team_id": 2, "ready": false }
  ]
}
```

Required seats are derived from the canonical mode and cannot be reduced by a
client-provided value:

- `1V1`, `PVP`, `CAPTURE_FLAG`, and `HIDDEN_CAPTURE_FLAG`: 2
- `3P FFA` / `3P_FFA`: 3
- `2V2` and `4P FFA` / `4P_FFA`: 4

Seats are contiguous for the active session contract and UIDs are unique.
For `2V2`, seats 1 and 3 are team 1 and seats 2 and 4 are team 2. A synchronized
session remains `waiting` until the roster is complete and may not become
`started` early. The contract hash binds the mode, required seat count, map/setup
inputs, and ordered `{seat, uid, team_id}` roster.

## Authenticated durable Standard 1v1

The public-v2 route slice is separately gated by `VS_DURABLE_CORE_ENABLED` and
`VS_DURABLE_PUBLIC_1V1_ENABLED`. Every request requires an ES256 player access
token with `match:queue` scope. The service derives player identity from token
`sub`; body `uid` or `player_id` fields are never authority.

Queue entry is `enqueue_public_1v1` with `protocol_version: 2`, a pinned
`client_build`, `request_id`, and an allowlisted `mode_id` (`STANDARD_1V1`,
`CTF_1V1`, or separately gated `HCTF_1V1`). The server supplies ruleset/map IDs and
hashes, simulation build, seats, teams, colors, rank policy, and economy policy.
The remaining actions are:

- `poll_public_1v1` and `cancel_public_1v1` by `ticket_id`.
- `get_public_1v1_session`, `set_public_1v1_ready`, `start_public_1v1`, and
  `leave_public_1v1` by `match_id`.
- `publish_public_1v1_command` with a stable `client_command_id`, and
  `poll_public_1v1_commands` with `after_seq`.
- `resume_public_1v1` to restore the authenticated player's newest live match
  and original seat during the stored reconnect grace period.
- `get_public_bot_fallback_offer` to read server-time eligibility for a waiting
  CTF/HCTF ticket, and `accept_public_bot_fallback` for explicit, idempotent
  conversion into a separate canonical-bot practice contract. Acceptance
  cancels the human ticket; it never mutates the ticket into a bot opponent.

Mutating lifecycle requests require a stable `request_id`. Reads do not.
`roster[]` is canonical in all matched/session responses; `host` and `guest` are
derived compatibility projections. The Package 1 proof slice is unranked and
non-economic. The public durable path remains non-economic and freezes rank
eligibility only when `VS_ENABLE_PUBLIC_1V1=true`; its server-owned authority
tier must also be `AUTHORITY_VERIFIED`.

### Trusted Standard 1v1 and visible CTF result verification

This separately gated path requires `VS_MATCH_VERIFICATION_ENABLED=true`, both
durable gates, an `AUTHORITY_VERIFIED` frozen contract, and migration 003.

Authenticated roster members call `submit_public_1v1_terminal_report` with a
stable `request_id`, `match_id`, final-state hash, elapsed ticks, claimed terminal
reason/winner, and bounded diagnostics. These fields are replay hints only. Once
both roster reports exist, the service creates one stable verification job.
`get_public_1v1_result` returns report count, pending/leased/completed status, and
the immutable result and detached signed receipt when available.

The separately deployed verifier uses `x-verifier-worker-token`—never a player or
admin credential—to call `lease_match_verification`,
`complete_match_verification`, and `fail_match_verification`. Completion requires
an ES256 signature over canonical JSON and exact binding to result ID, contract,
epoch, command high-water/hash, simulation and worker builds, verification time,
and key ID. A stale epoch, changed input, wrong signer, or malformed placement
fails closed. Rank and economy are separate disabled consumers and are not
mutated by these routes.

Visible `CTF_1V1` uses the same result path with its frozen CTF rules/map hashes
and remains unranked. `CTF_BOT`/`HCTF_BOT` practice is excluded. Human HCTF is
also excluded until live hidden-state secrecy exists; post-match replay cannot
prevent an opposing peer from inspecting hidden state during play.

### Standard 1v1 settlement and Global Rank

Migration 004 stores one settlement job per signed verified result. Reconciliation
selects only `STANDARD_1V1`, `AUTHORITY_VERIFIED` contracts with frozen enabled
rank policy. Delivery to Rank uses a short-lived ES256 service JWT and forwards
the detached verifier receipt; `rank_event_id` must equal the receipt's immutable
`result_id`. Retryable failure remains durable and `get_public_1v1_result` includes
the roster member's settlement status.

`get_public_global_rank` is a public read controlled by
`VS_ENABLE_PUBLIC_LEADERBOARDS`. It proxies Rank's shared Global board. Responses
include `generated_at`, `cache_age_seconds`, `stale`, and `source`. Only a bounded
previous server snapshot may be used during outage; no local leaderboard is a
valid fallback.

`VS_ENABLE_PUBLIC_1V1`, `VS_ENABLE_RANK_MUTATIONS`, and
`VS_ENABLE_PUBLIC_LEADERBOARDS` default false and are independent.

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

For a 3- or 4-seat mode, the same invite remains joinable until `roster` reaches
`required_players`. Intermediate responses use `status: "waiting"`; the final
seat completes the handshake.

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

For paid money-game sessions, any response that marks a session `started` must only succeed after ledger escrow is open for every player in the session. This includes invite joins and quick-match pairings that auto-start locally, plus explicit `start_session` calls. The escrow operation uses integer cents and idempotency as defined in `docs/money_game_ledger_contract.md`.

Paid session context must include:

```json
{
  "price_usd": 1,
  "wager_cents": 100,
  "free_roll": false,
  "paid_entry": true,
  "ledger_status": "escrowed",
  "pot_cents": 200
}
```

The local smoke backend accepts optional profile balance hints for paid-session testing:

```json
{
  "profile": {
    "uid": "u1",
    "display_name": "Host",
    "balance_cents": 1000
  }
}
```

Production backends should ignore client-provided cash balances and use the authoritative wallet/payment account instead.

### `open_money_escrow`
Request:
```json
{
  "session_id": "S12345678",
  "player_ids": ["u1", "u2"],
  "wager_cents": 100,
  "idempotency_key": "open:S12345678"
}
```
Response:
```json
{
  "ok": true,
  "type": "escrow_opened",
  "session_id": "S12345678",
  "status": "escrowed",
  "pot_cents": 200,
  "escrow_cents": 200
}
```

### `settle_money_match`
Request:
```json
{
  "session_id": "S12345678",
  "winner_id": "u1",
  "idempotency_key": "settle:S12345678:u1"
}
```
Response:
```json
{
  "ok": true,
  "type": "match_settled",
  "session_id": "S12345678",
  "status": "settled",
  "winner_id": "u1",
  "winner_payout_cents": 180,
  "house_rake_cents": 20,
  "pot_cents": 200
}
```

### `refund_money_match`
Request:
```json
{
  "session_id": "S12345678",
  "reason": "failed_start",
  "idempotency_key": "refund:S12345678"
}
```
Response:
```json
{
  "ok": true,
  "type": "match_refunded",
  "session_id": "S12345678",
  "status": "refunded",
  "refund_reason": "failed_start",
  "refunded_cents_per_player": 100
}
```

### `open_async_entry_escrow`
Request:
```json
{
  "entry_id": "async:WEEKLY_USD_5_2026W26:u1:12345",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "player_id": "u1",
  "wager_cents": 500,
  "idempotency_key": "open:async:WEEKLY_USD_5_2026W26:u1:12345"
}
```
Response:
```json
{
  "ok": true,
  "type": "async_entry_escrowed",
  "entry_id": "async:WEEKLY_USD_5_2026W26:u1:12345",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "player_id": "u1",
  "status": "escrowed",
  "wager_cents": 500,
  "pot_cents": 500,
  "escrow_cents": 500
}
```

Async paid contest clients must derive `contest_id` and `wager_cents` from the selected `ContestDef`; paid denomination selection is exact, not nearest-match fallback. The backend still validates funds and posts the escrow debit authoritatively.

### `settle_async_contest`
Request:
```json
{
  "contest_id": "WEEKLY_USD_5_2026W26",
  "winner_id": "u1",
  "idempotency_key": "settle:WEEKLY_USD_5_2026W26:u1"
}
```
Response:
```json
{
  "ok": true,
  "type": "async_contest_settled",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "status": "settled",
  "winner_id": "u1",
  "winner_payout_cents": 900,
  "payout_total_cents": 900,
  "payout_count": 1,
  "house_rake_cents": 100,
  "pot_cents": 1000
}
```

### `settle_async_contest_payout_percentages`
Request:
```json
{
  "contest_id": "WEEKLY_USD_5_2026W26",
  "house_rake_bps": 1000,
  "payouts": [
    {"placement": 1, "player_id": "u1", "payout_bps": 4000},
    {"placement": 2, "player_id": "u2", "payout_bps": 2000},
    {"placement": 3, "player_id": "u3", "payout_bps": 1500},
    {"placement": 4, "player_id": "u4", "payout_bps": 1000},
    {"placement": 5, "player_id": "u5", "payout_bps": 1500}
  ],
  "idempotency_key": "settle:WEEKLY_USD_5_2026W26:top5"
}
```
Response:
```json
{
  "ok": true,
  "type": "async_contest_settled",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "status": "settled",
  "winner_id": "u1",
  "winner_payout_cents": 18000,
  "payout_total_cents": 45000,
  "payout_count": 5,
  "house_rake_cents": 5000,
  "player_pool_cents": 45000,
  "payout_basis": "post_rake_pool",
  "pot_cents": 50000
}
```

The percentage payout-table settlement must balance exactly against the post-rake player pool: `sum(payouts.payout_bps) == 10000`. The ledger calculates house rake from gross escrow first, then calculates each paid placement from the remaining player pool and posts one transaction per paid placement.

### `preview_async_contest_payout_report`
Builds and persists the dashboard approval report before money moves. The response includes `players_count`, `entries_count`, `paid_entries_count`, `total_take_cents`, `house_rake_cents`, `player_pool_cents`, and `planned_payouts`.

The report must be persisted with `approval_status: "pending_approval"`. A client that successfully queues a scheduled contest report mirrors that contest as `PAYOUT_PENDING`.

### `submit_async_contest_result`
Submits one entrant's terminal async contest result into the backend result ledger. Race and Miss-N-Out money contests use this before closeout so ops approval can rank the full contest field, not only the local client row.

Request:
```json
{
  "contest_id": "WEEKLY_USD_15_2026-W26_RACE",
  "contest_family": "RACE",
  "player_id": "p1",
  "result": {
    "player_id": "p1",
    "run_id": "run_123",
    "map_count": 3,
    "completed_maps": 3,
    "map_times_ms": [61000, 63000, 64000]
  },
  "idempotency_key": "submit_result:WEEKLY_USD_15_2026-W26_RACE:p1:run_123"
}
```

### `list_async_contest_results`
Returns backend-submitted terminal result rows for a contest, sorted by the contest-family ranking rule.

Request:
```json
{ "contest_id": "WEEKLY_USD_15_2026-W26_RACE", "contest_family": "RACE" }
```

### `preview_async_contest_result_payout_report`
Ranks backend-submitted result rows, applies the dashboard payout percentage table, and queues a pending payout approval report. This is the preferred closeout path for Race and Miss-N-Out money contests.

Request:
```json
{
  "contest_id": "WEEKLY_USD_15_2026-W26_RACE",
  "contest_family": "RACE",
  "map_count": 3,
  "payout_schedule": [
    { "placement": 1, "payout_bps": 7000 },
    { "placement": 2, "payout_bps": 3000 }
  ],
  "house_rake_bps": 1000
}
```

The report source must indicate backend result authority, and ops review should block approval when the backend result set is missing or has fewer qualified rows than planned payout rows.

### `list_async_contest_payout_reports`
Returns persisted payout approval reports for the ops console. Supports `status`/`approval_status`, `contest_id`, `report_id`, `sort_desc`, and `limit`.

### `get_money_payout_summary`
Returns posted payout totals for proof/reporting: total paid out, house rake, gross closed amount, payout/rake transaction counts, pending approval count, and recent contest payout summaries. Totals are derived from ledger transaction rows.

### `approve_async_contest_payout_report`
Approves a pending report and posts payout/rake ledger rows with `approval_id` and `approved_by`. A successful approval returns `approval_status: "approved"` and the approved report; the client mirrors the contest as `PAYOUT_APPROVED`.

Approval failure rules:

- Missing idempotency key returns `missing_idempotency_key`.
- Missing approver returns `missing_approver_id`.
- Repeating the same idempotency key returns the cached result and posts no duplicate transactions.
- Re-approving an already approved report with a new idempotency key returns `approval_report_already_approved`.
- Approving a report whose status is not `pending_approval` returns `approval_report_not_pending`.

### `refund_async_entry`
Request:
```json
{
  "entry_id": "async:WEEKLY_USD_5_2026W26:u1:12345",
  "reason": "failed_start",
  "idempotency_key": "refund:async:WEEKLY_USD_5_2026W26:u1:12345"
}
```
Response:
```json
{
  "ok": true,
  "type": "async_entry_refunded",
  "entry_id": "async:WEEKLY_USD_5_2026W26:u1:12345",
  "status": "refunded",
  "refunded_cents": 500
}
```

### `get_money_transactions`
Request:
```json
{
  "session_id": "S12345678",
  "sort_desc": true,
  "limit": 20
}
```
Response:
```json
{
  "ok": true,
  "transactions": []
}
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
  "context": { "mode": "PVP", "map_count": 1, "price_usd": 0, "wager_cents": 0, "free_roll": true, "paid_entry": false }
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
