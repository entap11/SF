# ADR 001: Platform Economy and Progression Authority

Status: Accepted and implemented in the certification environment
Date: 2026-08-17

## Scope and authorization boundary

This ADR is the authoritative target contract for Honey, Wax, Nectar, and the
Crucible Wax reserve. It supersedes any ownership, reset, or Crucible payout
statement that conflicts with it.

Execution was separately authorized after the discovery block. Platform ledger,
receipt, entitlement, progression, epoch, and VS delivery schemas are deployed
to certification. The beta epoch was activated only after quiescence,
reconciliation, pinned-artifact, and backup/restore gates passed. Capability
activation remains separate and default-off.

## Pre-implementation context (resolved or quarantined)

Before this ADR was implemented, the code did not have one platform economy
authority:

- Honey is written by client autoloads and a VS ledger whose configured default
  store is `data/honey-ledger.json`.
- Wax is written by Rank PostgreSQL, local `RankState` fallback code, local
  `CrucibleState`, the legacy VS Crucible ledger, and a newer VS PostgreSQL
  Crucible settlement ledger.
- Nectar is written only into client save files. There is no server progression
  store or trusted-event consumer.
- The durable VS Crucible repository has the correct `1000 + 1000 -> 1800 +
  200` accounting, but its accounts and escrow are transactionally coupled to
  VS contract/result tables. Its accounting semantics are reusable; its
  permanent-wallet ownership and cross-table layout are not the target.

The complete current-to-target classification is in
[current-target-writer-matrix.md](current-target-writer-matrix.md).

## Decision

The existing ENTaP-authenticated PostgreSQL service boundary becomes the
**Platform Economy/Progression authority**. This may initially be deployed in
the existing Rank service process and database, but “Platform” is the domain
boundary; Honey and Nectar are not Rank concepts.

| Concept | Sole canonical writer | Other systems |
| --- | --- | --- |
| Identity | ENTaP identity authority | Supply canonical player identity |
| Honey | Platform Economy | Clients request allowed spends and read projections; trusted producers submit facts |
| Wax available balance and custody | Platform Economy | Rank derives tier/position; VS coordinates Crucible |
| Nectar and seasonal progression | Platform Progression | Clients submit genuine claim intents and read projections; trusted producers submit facts |
| Rank tier, position, percentile | Rank projection logic | Derived from canonical Wax and identity |
| Match and Crucible lifecycle | VS | Produces durable, authenticated facts; never writes permanent player wealth |
| Match outcome | Trusted verifier/authority | Produces signed, immutable result facts |

Each future concept has exactly one writer. A client, UI, render system, VS
lifecycle handler, local save, file store, and debug endpoint may not be a
production economic writer.

## Shared mutation contract

All Honey, Wax, and Nectar mutations use one transaction and audit contract.

### Canonical producer envelope

Every producer fact contains:

- `producer_service`
- `producer_event_id`
- `event_type`
- `subject_player_id` (or an explicit multi-account subject)
- `economy_epoch`
- `source_authority`
- `occurred_at`
- `schema_version`
- canonical payload
- `source_result_id`, `match_id`, `season_id`, `contest_id`, `hive_id`, or
  `escrow_id` when applicable

Platform may also assign its own `event_id`, but that ID does not replace the
producer identity.

The database must enforce a unique constraint on
`(producer_service, producer_event_id)`. The first accepted request stores a
canonical request hash and its committed response/side-effect receipt.

- Same producer key and same canonical request returns the original committed
  receipt and creates no second mutation.
- Same producer key and a different canonical request fails with an idempotency
  conflict.
- A receipt may not report success until the journal and materialized balances
  have committed in the same database transaction.

This is the persistence invariant underneath at-least-once delivery. In-memory
dedupe and a consumer-created event UUID are insufficient.

### Mutation invariants

- PostgreSQL is the production authority. Production must fail closed if an
  authoritative store resolves to memory or a file.
- Economic quantities are integers in their canonical units.
- Clients and producer services submit facts or allowed action intents, never
  authoritative reward amounts.
- Platform authenticates the caller, authorizes the event/action, calculates
  the amount, checks the epoch and policy version, and commits the journal and
  materialized balance atomically.
- Every accepted mutation has an immutable journal entry. Balance tables and
  rank/progression projections are materialized views of that history, not a
  second source of truth.
- Corrections use explicit reversal/adjustment events. Direct database balance
  edits are not an operational path.
- Old-epoch, out-of-order, altered, unauthorized, and insufficient-funds
  mutations fail without a partial journal or balance change.
- Each mutation family has an independent, default-off capability gate.

## Honey contract

Honey is a Platform wallet denominated in integer centi-Honey. Match and
activity producers submit authenticated facts; Platform owns the reward table
and calculates the credit. A purchase client submits a product/action intent;
Platform owns price validation and the debit.

Hive proportional purchases use a Platform-authored membership and balance
snapshot captured inside the purchase transaction. Active-member eligibility
must be frozen by product policy before implementation. Contributions use
largest-remainder apportionment, with ascending canonical player UUID as the
final tie-break. The sum of member debits must equal the purchase cost exactly.
Membership changes after the locked snapshot do not change that purchase.

## Wax and Crucible contract

Wax uses integer milli-Wax (`1000 wax_millis = 1 Wax`). Available balance is
canonical economic/rank value. Tier, percentile, and leaderboard position are
derived metadata and are not spendable balances.

For `CRUCIBLE_WAX_V1`:

- Platform reserves exactly `1000 wax_millis` from each participant.
- The contract is not startable until VS durably holds both original Platform
  reservation receipts for the pinned contract and economy epoch.
- Total escrow is exactly `2000 wax_millis`.
- A verified winner receives exactly `1800 wax_millis`.
- Exactly `200 wax_millis` credits the canonical Platform ledger account
  `reserve:award`.
- A qualifying no-contest/refund returns exactly `1000 wax_millis` to each
  participant.
- Reserve, settle, and refund are separately idempotent and mutually exclusive
  terminal operations.

`reserve:award` is a literal canonical Platform ledger account key/journal
destination, not a label or burn. Its physical row identity is epoch-scoped so
a later epoch cannot collide with or inherit an earlier reserve. Credits are immutable. There is no authorized
debit path until a later product contract explicitly defines one. Application,
admin, and database tooling may not spend or manually transfer it.

Wax conservation is:

> player available balances + open escrow + award reserve + any other defined
> custody accounts = epoch opening value + authorized Wax issuance - formally
> recorded permanent sinks

The reserve is custody and therefore remains on the left side; it is not a
permanent sink.

Moving custody out of VS removes the current shared-database foreign-key
transaction. The replacement is an explicit saga:

1. VS creates and freezes a contract.
2. VS requests two Platform reservations using the pinned contract ID/hash,
   roster, policy version, economy epoch, and expiry.
3. Platform commits each reservation and returns an immutable receipt.
4. VS marks the contract startable only after validating and durably recording
   both receipts.
5. The trusted result is delivered at least once through the VS outbox.
6. Platform settles or refunds exactly once and returns the original receipt on
   retry.
7. Reconciliation repairs missed delivery and expires/refunds orphaned
   reservations according to the frozen timeout policy.

No step relies on a distributed transaction.

## Nectar contract

Nectar is seasonal progression owned by Platform Progression. Trusted match,
contest, challenge, and purchase facts cause server-side policy evaluation.
The client does not ask to be awarded Nectar for a match the server already
observed. Client mutation is limited to genuine player actions such as claiming
an available reward or selecting an entitlement.

Nectar uses integer milli-Nectar wherever multipliers can create fractions.
Fractional carry is authoritative server state. If pass level is fully
determined by thresholds, it is a projection of seasonal Nectar rather than an
independent writer.

Multiplier order, rounding point, cap behavior, challenge applicability,
season rollover, and claim semantics must be frozen before implementation.

## Delivery, reconciliation, and service trust

- Producers use a transactional durable outbox for facts emitted alongside
  their own state changes.
- Delivery is at least once; Platform consumption is idempotent under the
  database uniqueness rule above.
- Service-to-service calls require authenticated service identity and
  event-type authorization. Player credentials cannot impersonate a producer.
- Reconciliation compares producer facts/outbox state, Platform receipts,
  immutable journal entries, materialized accounts, custody, and projections.
- Exact integer reconciliation is required; tolerated unexplained divergence is
  zero.

Existing VS idempotency, outbox, request hashing, receipts, immutable match
results, reconciliation workers, and Rank transactional/audit machinery are
the reuse baseline. They must be generalized at the Platform boundary rather
than copied into three unrelated implementations.

## Economy epoch transition

An economy reset is one coordinated state machine:

`DRAFT -> PREPARED -> RECONCILED -> ACTIVE`

Any failed pre-activation transition ends in `ABORTED`; it must never partially
activate. `ACTIVE` is immutable.

`PREPARED` requires mutations off, no startable/active economic matches, no
unresolved Crucible custody, drained/reconciled outboxes, a verified restorable
backup, and pinned deployment/config artifacts. Reset adjustments are audited
ledger events under the transition; identity is preserved. Clients discard
old-epoch projections only after `ACTIVE` is published.

The requested beta opening values are Honey `0`, Wax `0`, and Nectar `0` for
the new season. Wax is currently coded with a floor/base of `100`; removing or
changing that rule is an explicit product decision and code change, not a data
reset shortcut.

## Rollout order and GO boundary

Rollout is independently gated:

1. Read paths only.
2. Nectar.
3. Honey earn.
4. Honey spend.
5. Standard Wax.
6. Crucible reserve/settlement.

Each capability progresses `OFF -> allowlist -> bounded canary -> reconcile ->
GO/HOLD`. Passing one does not authorize the next. Economy GO is separate from
overall game-release GO.

## Consequences

- Honey and Nectar can share the existing deployment boundary without being
  described as Rank-owned product concepts.
- VS remains responsible for lifecycle evidence and delivery but no longer owns
  permanent player wallets or the award reserve.
- Current client saves remain useful only as replaceable/offline presentation
  projections after migration.
- The current VS PostgreSQL Crucible implementation is a valuable reference and
  transition source, but not the final authority.
- No additional third-party product is required by this architecture. Managed
  PostgreSQL, identity, observability, and deployment vendors are operational
  choices, not correctness dependencies.
