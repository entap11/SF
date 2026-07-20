# Package 9 Evidence Report — Crucible Settlement Correction

Program mapping: Sharpened readiness Program Package 9; code-grounded execution revision Package 10  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- Crucible now freezes integer Wax accounting at 1,000 millis per player,
  2,000 escrowed, 1,800 paid to the verified winner, and 200 transferred to the
  award reserve. A valid cancellation refunds exactly 1,000 to each player.
- Migration `008_crucible_settlement.sql` adds durable accounts, escrows,
  balanced journal lines, settlements, refunds, reversals, and restart-safe
  idempotency receipts. Every transaction is double-entry and must sum to zero.
- `PostgresCrucibleSettlementRepository` derives both participants from the
  immutable `CRUCIBLE_1V1` roster. Winner settlement requires a matching
  Authority Verified terminal result and signed verifier receipt; the caller
  cannot provide a winner or reserve account.
- Settlement reversal stores an explicit reference to the original settlement
  transaction, unwinds winner and reserve movements, and refunds both stakes.
  Reconciliation compares per-transaction balance and stored account balances
  against the immutable journal.
- Ops-only metrics expose reserve, open escrow, settlement/refund, journal
  imbalance, and reconciliation counts. Admin and match-authority credentials
  remain separate.
- Public Crucible uses the certified durable 1v1 queue/roster/command path with
  `CRUCIBLE_WAX_V1`; it is unranked and does not enter ordinary rank settlement.
  The server opens escrow after a matched authenticated roster is frozen.
- The GDScript preview, lobby metadata, confirmation, outcome copy, local-dev
  settlement adapter, and smokes use the same 1,000/1,800/200 constants. The
  legacy `burn` field remains zero only for wire compatibility; no
  `crucible_burn` account receives value.
- The stale ruleset smoke no longer requires the removed `EconomyBuffState`
  autoload and checks the current Crucible purity policy directly.
- `VS_ENABLE_PUBLIC_CRUCIBLE` and `VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT` are
  independent and default false.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–008 under embedded PostgreSQL: `PASS`.
- Durable Crucible settlement smoke: `PASS`.
  - Exact debit, payout, reserve, and cancellation refund amounts.
  - Zero journal imbalance and zero reconciliation divergence.
  - Duplicate settlement/refund/reversal returned original durable receipts
    through a new repository instance (restart simulation).
  - Verified-result winner derivation and explicit reversal references.
- VS full smoke, economy quarantine, and durable 1v1 regressions: `PASS`.
- Godot Crucible ruleset, arena settlement, lobby escrow, online flow, and
  outcome-overlay smokes: `PASS`.

## Authority and safety boundaries

- Player-authenticated queue requests can neither settle nor choose a winner.
- Match authority may open escrow and commit only an already verified result.
- Refunds, reversals, balance administration, and reserve metrics require ops
  authentication.
- No API accepts a reserve destination. The canonical key is
  `reserve:award`, created by migration.
- PostgreSQL account constraints prevent negative player, escrow, and reserve
  balances. The system issuance counter-account is used only for audited ops
  balance initialization/adjustment.

## Deliberate release gates

- No environment was migrated and neither feature flag was enabled.
- Production Wax balance import/source-of-truth reconciliation, managed
  PostgreSQL restart/backup restore, real authority-worker certification, and
  two-device Crucible staging remain required before public release.
- The legacy file-backed ledger is retained as a quarantined/local adapter; it
  is not an authorized public settlement store.

## Rollback

- Keep both Crucible flags false. Preserve migration 008 and its journal for
  audit; do not delete settlement history during application rollback.
- Revert the package commit to restore client copy/preview behavior while the
  public route remains gated.

## Proposed next package

Implement Package 10: durable free async 3-map and 5-map rolling four-player
cohorts, atomic fourth-result closure, top-three snapshots, and idempotent
placement messages for all four entrants.
