# Daily and weekly quests: authoritative backend

Status: historical first-slice design, superseded by [quest v1 implementation](quest_v1_implementation.md).
The configured catalog, scheduler, contest activity delivery and full-week bonus are now implemented locally; beta remains disabled.

This slice adds quest progress and claims to the existing Platform economy in
`tools/rank-service`. It does not enable the legacy client reward writers.

## Implemented

- A validated, server-owned catalog with multiple objectives per quest. Objectives
  can filter mode IDs, paid/free entry, and wins, and count completed matches.
- Progress persisted in PostgreSQL, scoped to player, economy epoch, quest, and
  cycle. Match delivery retries count once, including deliveries with a different
  producer event ID for the same match.
- Progress updated in the same transaction as an accepted trusted Nectar match
  fact, under the existing Nectar capability gate. No player-facing endpoint
  accepts progress or completion reports.
- Read and claim APIs authenticated with existing player sessions.
- Fixed Honey and/or Nectar rewards committed atomically with the claim through
  the existing immutable journal. Capability gates apply to each reward asset.
- Existing account-deletion cleanup includes the new progress records, subject
  to the existing financial-record retention checks.

The production catalog in `platformQuests.ts` is intentionally empty. The
[24 daily quests are approved as content v1](daily_quest_catalog_v1.md), and the
[four weekly quests have a separate proposal](weekly_quest_catalog_draft.md).
Neither is enabled. Example objectives in the smoke test remain test fixtures.

## Cycle and reward contract for this slice

- Daily cycles begin at 00:00 UTC. Weekly cycles begin Monday at 00:00 UTC.
- Definitions have explicit launch/end timestamps. Pre-launch games do not count.
- Trusted event occurrence time chooses the cycle; device time is never used.
  Late delivery updates its original cycle. Future-dated facts do not advance
  quests. Completed claims can be retried after rollover to recover the receipt.
- New claims must arrive before the cycle ends. There is no grace period in this
  slice. Unclaimed expired rewards cannot be collected.
- Every objective must reach its target. A game can advance each applicable
  objective once; counters stop at their targets.
- Match eligibility follows the existing Nectar policy, with explicit completed
  match evidence and a match ID required. Crucible does not count in this slice.
- The first qualifying match freezes the definition and reward for that player's
  cycle. Further delivery and claims use that saved definition. Catalog entries
  should remain stable for their published window; schedule changes at cycle
  boundaries. The read API shows frozen assignments through their cycle end.
- Honey uses integer centi-Honey; Nectar uses integer milli-Nectar. Quest rewards
  are fixed amounts: no pass multiplier, match farming multiplier, or match daily
  soft cap applies to the bonus. Claiming Nectar updates the existing progression
  projection and preserves its entitlement tier and fractional carry.
- Claim retries use the same request ID, epoch, quest ID, and cycle start. Changed
  payloads conflict; a second request ID cannot pay an already claimed quest again.
- All progress and claims are isolated by economy epoch. Old-epoch claims fail.

## API

`GET /v1/platform/quests/me` requires `economy:read` and an active player session.
It returns the current `epoch_id`, `season_id`, `server_time`, and `quests` with
objective progress, reward amounts, cycle boundaries, and claim status. Player
identity comes from the token.

`POST /v1/platform/quests/claim` requires `progression:claim` and an active session.
Send only:

```json
{
  "request_id": "unique-client-action-id",
  "epoch_id": "epoch-from-quest-snapshot",
  "quest_id": "id-from-quest-snapshot",
  "cycle_start": "2026-09-29T00:00:00.000Z"
}
```

The server reads progress and rewards from its own database. The receipt includes
the transaction ID, actual reward, balances, and pass level. The UI must refresh
the snapshot after failures or rollover and preserve the request ID for retries.

## Remaining work before a player-facing launch

1. Review the four weekly proposals, choose reward amounts, and finalize daily
   selection/rotation for the approved 24 daily entries. The current engine
   exposes every active definition; it does not select a subset.
2. Connect the game UI and transport to these read/claim APIs.
3. Confirm trusted producer coverage for each chosen mode. The existing VS
   delivery path supplies verified live match facts. This change does not add
   async/contest/paid-game producers; filters alone do not establish that coverage.
4. Define and implement Crucible participation objectives and double-Honey
   promotions if selected. Those need additional event/reward rules; the current
   Crucible suppression is preserved.
5. Deploy migration `014_platform_quests.sql` with the service, then validate the
   selected catalog and delivery paths before enabling live quests.

## Validation

`npm run build` and `npm run smoke:platform-economy` in `tools/rank-service` cover
catalog validation, combined objectives, eligibility exclusions, capped counters,
duplicate delivery, player/epoch isolation, frozen rewards, capability gates,
rollback after journal posting, claim retries, daily/weekly rollover, and late
delivery. The existing ledger reconciliation must still report zero drift and
zero unbalanced transactions. These are embedded database tests, not a deployed
canary or a real multi-connection PostgreSQL concurrency test.
