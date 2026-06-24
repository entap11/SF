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
