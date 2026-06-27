# Crucible Launch Runbook

Status: first-pass implementation guardrail.

## Match Model

- Player-facing entry: separate Crucible lobby/queue.
- Code-facing match type: `vs_mode = "1V1"`.
- Canonical ruleset: `vs_ruleset = "CRUCIBLE"`.
- Derived flags: `vs_crucible = true`, `is_crucible_match()`.

Crucible is a ruleset overlay on normal 1V1 map shape. It must remain mechanically pure: no buffs, consumables, loadout advantages, store prompts, Honey, Nectar, Battle Pass gameplay modifiers, paid modifiers, or normal rank Wax payout.

## Launch Economy Defaults

Current first-pass defaults:

- Stake: `stake_bps = 500` of the lower player Crucible Wax balance.
- Burn: `burn_bps = 1000` of the pot.
- Minimum stake: `minimum_stake_millis = 1000`.
- Starting Crucible Wax: `0`.
- Launch grant: disabled by default.
- Local dev settlement: disabled in production, allowed only behind config for smoke/dev.

All values are versioned by `config_version` and `config_hash`. Clients should refresh config before queue confirmation and pass the expected version/hash into escrow open.

## Ops Controls

The Ops console can change:

- Crucible enabled / queue enabled.
- Wagering enabled.
- Ads enabled.
- Capacity cap enabled, max capacity, reserved slots.
- Settlement enabled.
- Earn-path buttons enabled.
- Server-authoritative settlement required.
- Local-dev settlement enabled.
- Launch grant enabled and amount.
- Stake bps, burn bps, minimum stake, rounding mode.
- Standard PvP/tournament/challenge/event earn-path values.

The Ops console also supports:

- Ledger refresh.
- Ledger filter by match/player/status/type.
- CSV export of filtered ledger/audit rows.
- Held-review refund/approve action.

## Backend Deployment Env

Required for production:

- Supabase Postgres-backed Crucible repository.
- Supabase Auth as user/admin identity provider.
- Backend validation of Supabase identity for all privileged operations.
- Backend-issued short-lived signed JWTs for admin operations and match-authority operations.
- `CRUCIBLE_LEDGER_STORE=postgres` once the Postgres adapter is wired.
- JSON/file adapter only for local dev and tests.

The current durable adapter is pluggable and defaults to JSON file persistence. Production is pinned to Supabase Postgres; implement the Postgres adapter behind the same `CrucibleLedgerStore` boundary before production launch. Do not trust client-provided authority tokens in production. The backend should validate Supabase Auth claims and mint short-lived signed admin/match-authority JWTs.

## Health Checks

`GET /health` and `GET /v1/health` include:

- Crucible storage kind.
- Configured storage kind/path.
- Whether admin auth is required.
- Whether match-authority auth is required.

Do not open the queue in production unless Supabase identity validation, short-lived admin/match-authority JWTs, and the Supabase Postgres ledger adapter are active.

## Settlement Rules

- Escrow is opened before match start.
- Winner settlement accepts only authoritative result sources.
- UI/client-only result sources become no-contest refunds.
- Draw/no-winner/invalid result refunds both players.
- Voluntary quit, forfeit, and post-start disconnect settle as a loss unless server/network fault invalidates the match.
- Cancel before first authoritative tick refunds both.
- Desync/no-contest refunds both with no burn.

## Review Holds

High-risk anti-collusion signals hold settlement instead of paying out:

- unusual win trading
- same device cluster
- same IP pattern
- suspicious forfeit
- high-stakes repeated transfer
- repeated same opponent at high stake

Held settlements have `settlement_status = "HELD_REVIEW"`, no burn, and no winner payout until Ops resolves the review.

Ops actions:

- `refund`: returns both escrows, burns nothing.
- `approve`: releases winner payout and burn.

## Audit Fields

Every settlement/audit record should include:

- `match_id`
- `ruleset`
- `player_a_id`
- `player_b_id`
- `stake_each`
- `pot`
- `burn`
- `winner_payout`
- `winner_id`
- `loser_id`
- `result_source`
- `config_version`
- `settlement_status`
- `created_at`

Backend records also include idempotency and review metadata where applicable.
