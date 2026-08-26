# Honey v2 First-Pass Wiring

Status: first production-facing wiring pass, still ops-gated.

Source docs:

- `docs/legal_hive_governance_sources/ENTaP_Honey_Economy_v1.pdf`
- `docs/legal_hive_governance_sources/ENTaP_Honey_Economy_v2.pdf`

## Canonical Model

- Honey belongs to the player.
- A Hive has no separate Honey wallet or treasury.
- A Hive's purchasing power is the sum of current member Honey balances.
- Hive purchases deduct from all participating members proportionally to current balance.
- Every member sacrifices the same percentage of their Honey holdings.
- Public Hive identity and Honey records must not expose financial identity.

## Reward Ladder

Honey uses centi-Honey internally and whole Honey in the player profile/UI.

- Community: 1 Honey
- Engagement: 2 Honey
- Competitive participation: 4 Honey
- Competitive success: 8 Honey
- Platform growth: 16 Honey

Paid competitive activities currently award more than free activities, but stay within a moderate range so free players still progress.

Competitive Honey requires 120 seconds of authoritative completed match time: 2:00 is eligible and 1:59 is not.

## Current Code

- `scripts/state/honey_progression_state.gd`
  - centi-Honey precision
  - whole-Honey profile deposits
  - idempotent event awards
  - ops-gated reward enablement
  - Crucible suppression
  - opportunistic backend Honey grant posts when the VS backend is configured
  - platform growth, referral, engagement, objective, match, tournament, and contest hooks

- `scripts/state/vs_handshake_state.gd`
  - Honey balance, policy, activity-record, grant, debit, transaction, and Hive proportional purchase transport methods

- `scripts/state/hive_clan_state.gd`
  - local member Honey balance snapshots
  - proportional Hive purchase preview
  - proportional member-owned debit helper
  - Hive tournament entry now records per-member Honey deductions

- `tools/vs-service/src/honeyLedger.ts`
  - local/dev backend Honey ledger
  - player-owned centi-Honey balances
  - idempotent grant/debit operations
  - server-side activity recording through the Honey policy layer
  - proportional member-owned Hive purchase debit
  - transaction filtering and health/readiness visibility

- `tools/vs-service/src/honeyEconomyPolicy.ts`
  - ENTaP-oriented activity keys
  - expected duration per repeatable activity
  - time normalization for comparable Honey per active play time
  - no reward for early quit or below-minimum participation
  - same-opponent diminishing returns over a 24-hour window

## Remaining Platform Work

- Replace local member balance snapshots with canonical ENTaP player Honey balances.
- Replace the local/dev backend file adapter with the production ENTaP Honey ledger.
- Extend anti-farming policy to device/account clusters and cross-title abuse signals.
- Price Hive cosmetics, recruitment packages, tournament entries, and prestige items from measured earn rates.
