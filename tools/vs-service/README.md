# Swarmfront VS Service

Minimum VS handshake backend for two-phone TestFlight smoke tests.

This implements the routes in `../../docs/vs_backend_contract.md`. Production Crucible storage/auth is pinned to Supabase Postgres plus Supabase Auth, but the current service still uses local/dev adapters unless those production adapters are wired. Sessions, queue tickets, and intent streams reset when the process restarts.

## Local Run

```bash
cd tools/vs-service
npm install
npm run build
npm run smoke
npm run dev
```

Local base URL:

```text
http://127.0.0.1:8791/v1
```

## Routes

- `GET /health`
- `GET /v1/health`
- `POST /v1/create_invite`
- `POST /v1/join_invite`
- `POST /v1/get_session`
- `POST /v1/set_ready`
- `POST /v1/can_start`
- `POST /v1/start_session`
- `POST /v1/leave_session`
- `POST /v1/enqueue_quick_match`
- `POST /v1/poll_quick_match`
- `POST /v1/cancel_quick_match`
- `POST /v1/open_money_escrow`
- `POST /v1/settle_money_match`
- `POST /v1/refund_money_match`
- `POST /v1/open_async_entry_escrow`
- `POST /v1/settle_async_contest`
- `POST /v1/preview_async_contest_payout_report`
- `POST /v1/list_async_contest_payout_reports`
- `POST /v1/approve_async_contest_payout_report`
- `POST /v1/settle_async_contest_payout_percentages`
- `POST /v1/refund_async_entry`
- `POST /v1/get_money_transactions`
- `POST /v1/get_money_payout_summary`
- `POST /v1/get_honey_balance`
- `POST /v1/get_honey_policy`
- `POST /v1/record_honey_activity`
- `POST /v1/grant_honey`
- `POST /v1/debit_honey`
- `POST /v1/preview_hive_honey_purchase`
- `POST /v1/debit_hive_honey_purchase`
- `POST /v1/get_honey_transactions`
- `POST /v1/get_wax_policy`
- `POST /v1/record_competitive_wax_result`
- `POST /v1/publish_intent`
- `POST /v1/poll_intents`
- `POST /v1/create_spectator_grant`
- `POST /v1/join_spectate`
- `POST /v1/poll_spectator_events`
- `POST /v1/publish_spectator_snapshot`
- `POST /v1/poll_spectator_snapshots`
- `POST /v1/leave_spectate`

The same `POST /<action>` routes are also available for hosts that prefer a root base URL.

## Environment

- `PORT`: HTTP port. Defaults to `8791`.
- `BIND_HOST`: bind host. Defaults to `0.0.0.0`.
- `VS_CORS_ENABLED`: defaults to `true`.
- `VS_SESSION_TTL_SEC`: defaults to `900`.
- `VS_QUEUE_TTL_SEC`: defaults to `90`.
- `VS_INTENT_STREAM_MAX_EVENTS`: defaults to `512`.
- `VS_SPECTATOR_ADMIN_TOKEN`: bearer token required to create spectator grants.
- `VS_SPECTATOR_LIVE_ENABLED`: set to `1` to allow live admin spectate.
- `VS_SPECTATOR_DEFAULT_DELAY_SEC`, `VS_SPECTATOR_MIN_DELAY_SEC`, `VS_SPECTATOR_MAX_DELAY_SEC`: delayed spectator bounds.
- `VS_SPECTATOR_PUBLIC_ENABLED`: keep disabled for beta unless separately reviewed.
- `VS_ADMIN_TOKEN`: admin auth for Crucible config/review/debug endpoints and Honey debug endpoints; required in production.
- `VS_ADMIN_ROLE`: local/dev expected admin role. Defaults to `ops_admin`.
- `VS_MATCH_AUTHORITY_TOKEN`: match-authority auth for Crucible escrow, settlement, lifecycle writes, Honey grant/debit writes, and competitive Wax result writes; required in production.
- `CRUCIBLE_LEDGER_STORE`: `file` or `memory` today; production target is `postgres`.
- `CRUCIBLE_LEDGER_PATH`: JSON snapshot path for the local/dev file-backed Crucible ledger. Defaults to `data/crucible-ledger.json`.
- `HONEY_LEDGER_STORE`: `file` or `memory` today; production target is the ENTaP player ledger.
- `HONEY_LEDGER_PATH`: JSON snapshot path for the local/dev file-backed Honey ledger. Defaults to `data/honey-ledger.json`.

Honey ledger notes:

- Honey is stored as integer `centi_honey`.
- `record_honey_activity` is the preferred award path; it calculates the reward server-side from activity key, expected duration, completion flags, and anti-farm signals.
- Mutating Honey writes require match-authority auth in this local service.
- Hive Honey purchases use member-owned proportional debits; there is no separate Hive treasury.
- The current file-backed ledger is a local/dev adapter. Production should replace it with the canonical ENTaP player Honey ledger and real identity validation.

Wax ledger notes:

- Canonical Wax is owned by the rank/ENTaP identity layer, not the VS Crucible ledger.
- `record_competitive_wax_result` is deprecated and suppressed for compatibility; it must not mint or subtract Wax.
- Approved async contest payout reports do not publish Wax into the Crucible ledger.
- Crucible only escrows, refunds, and pays out optional 1-Wax wagers. There is no burn.
- RankState `wax_score` is the current canonical local implementation of player Wax.

Production Crucible requirements:

- Supabase Postgres-backed `CrucibleLedgerStore`.
- Supabase Auth validation for users/admins.
- Backend-issued short-lived signed JWTs for admin and match-authority operations.
- No client-provided authority should be trusted for settlement, escrow, or privileged admin writes.

For Crucible launch operations, see `../../docs/economy/crucible_launch_runbook.md`.

## Deploy

Use any Node HTTPS host such as Render, Railway, or Fly. Most hosts terminate TLS for you and provide a public HTTPS URL.

Build command:

```bash
npm install
npm run build
```

Start command:

```bash
npm start
```

Set `PORT` only if your host does not inject it automatically.

After deployment, use this base URL in Godot:

```ini
swarmfront/vs/backend_url="https://YOUR_HOSTNAME/v1"
```

Verify before exporting TestFlight:

```bash
godot --headless --path ../.. --script res://scripts/dev/vs_pvp_smoke.gd --vs-smoke-backend-url=https://YOUR_HOSTNAME/v1
```

Local money-game transport smoke:

```bash
PORT=8791 BIND_HOST=127.0.0.1 npm start
SF_VS_BACKEND_URL=http://127.0.0.1:8791/v1 godot --headless --path ../.. --script res://tools/money_game_backend_transport_smoke_test.gd
```
