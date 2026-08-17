# Crucible Launch Runbook

Status: **historical first-pass implementation guardrail; not launch authority**.
Authority, settlement, reserve, and rollout are superseded by
[Economy ADR 001](../architecture/economy/adr-001-platform-economy-authority.md)
and the [writer matrix](../architecture/economy/current-target-writer-matrix.md).
Do not use this runbook to enable the beta economy.

## Match Model

- Player-facing entry: separate Crucible lobby/queue.
- Code-facing match type: `vs_mode = "1V1"`.
- Canonical ruleset: `vs_ruleset = "CRUCIBLE"`.
- Derived flags: `vs_crucible = true`, `is_crucible_match()`.

Crucible is a ruleset overlay on normal 1V1 map shape. It must remain mechanically pure: no buffs, consumables, loadout advantages, store prompts, Honey, Nectar, Battle Pass gameplay modifiers, paid modifiers, or normal rank Wax payout.

## Launch Economy Defaults

Historical first-pass defaults:

- Stake: exactly `minimum_stake_millis = 1000`, meaning 1 Wax from each player.
- Award reserve: exactly `200 wax_millis` from the `2000 wax_millis` pot; it is
  custody in the literal Platform `reserve:award` account, not a burn.
- Minimum stake: `minimum_stake_millis = 1000`.
- Starting local Crucible mirror: `0`; this mirror is not canonical. Target
  player Wax and Crucible custody are Platform-owned.
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
- Legacy stake/burn basis-point controls, minimum stake, and rounding mode. The
  target `1000 + 1000 -> 1800 + 200` contract is fixed and these controls may
  not alter it.
- Standard PvP/tournament/challenge/event earn-path values.

The Ops console also supports:

- Ledger refresh.
- Ledger filter by match/player/status/type.
- CSV export of filtered ledger/audit rows.
- Held-review refund/approve action.

## Historical Backend Deployment Notes

The following describes the superseded adapter plan and is retained only to
explain existing code:

- A proposed Supabase Postgres-backed Crucible repository.
- Proposed Supabase Auth as the user/admin identity provider.
- Proposed validation of Supabase identity for privileged operations.
- Proposed short-lived signed JWTs for admin and match-authority operations.
- The legacy `CRUCIBLE_LEDGER_STORE=postgres` switch.
- JSON/file adapters intended only for local dev and tests.

The legacy adapter defaults to JSON file persistence. Current code subsequently
added a separate VS PostgreSQL Crucible repository, but the target moves
accounts/custody to Platform. Never trust client-provided authority tokens;
service and player identities must be verified by their respective authority.

## Health Checks

`GET /health` and `GET /v1/health` include:

- Crucible storage kind.
- Configured storage kind/path.
- Whether admin auth is required.
- Whether match-authority auth is required.

Do not use these notes as an economy GO checklist. The target requires Platform
PostgreSQL custody, authenticated service facts, the reservation saga, and the
ADR 001 rollout gates; it does not require a particular PostgreSQL vendor.

## Settlement Rules

- Escrow is opened before match start.
- Winner settlement accepts only authoritative result sources.
- UI/client-only result sources become no-contest refunds.
- Draw/no-winner/invalid result refunds both players.
- Voluntary quit, forfeit, and post-start disconnect settle as a loss unless server/network fault invalidates the match.
- Cancel before first authoritative tick refunds both.
- Desync/no-contest refunds both; no value credits the award reserve.

## Review Holds

High-risk anti-collusion signals hold settlement instead of paying out:

- unusual win trading
- same device cluster
- same IP pattern
- suspicious forfeit
- high-stakes repeated transfer
- repeated same opponent at high stake

Held settlements have `settlement_status = "HELD_REVIEW"`; neither winner payout
nor award-reserve credit occurs until an authorized resolution.

Ops actions:

- `refund`: returns both escrows; the reserve receives nothing.
- `approve`: releases the exact `1800 wax_millis` winner payout and credits the
  exact `200 wax_millis` award reserve.

## Audit Fields

Every settlement/audit record should include:

- `match_id`
- `ruleset`
- `player_a_id`
- `player_b_id`
- `stake_each`
- `pot`
- `award_reserve`
- `winner_payout`
- `winner_id`
- `loser_id`
- `result_source`
- `config_version`
- `settlement_status`
- `created_at`

Backend records also include idempotency and review metadata where applicable.
