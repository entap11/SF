# Quest v1 implementation and local verification

Implemented locally on 2026-09-29. **No deployment, beta distribution, production
migration or remote configuration change was performed. All quest flags default off.**

Content: [24 daily templates](daily_quest_catalog_v1.md) and [4 weeklies](weekly_quest_catalog_v1.md).
The daily v1 table remains unchanged. Rewards are provisional: 2 Honey/40 Nectar
per daily, 8 Honey/200 Nectar per weekly, plus 10% quest Honey for a complete week.

## Behavior and authority

Rank assigns three daily quests and four weekly quests from a deterministic,
overlapping rotation. UTC midnight resets dailies; Monday UTC resets weeklies.
A persisted 25-row manifest freezes every definition and reward for the entire
week on the first read or qualifying activity. Catalog edits cannot silently
change tomorrow's already assigned rewards. Partial launch/end weeks do not
qualify for the full-week bonus.

The VS worker independently delivers `QUEST_ACTIVITY_V1` facts from signed,
authority-verified live results and committed verified contest attempts. Live
facts preserve mode IDs; contest facts preserve family, scope and map count.
Gauntlet facts require stage evidence of natural termination. Every attempt
counts independently of personal-best standings. Abandoned runs do not count.
Duration uses integer simulation seconds, excluding scoring penalties.

Rank deduplicates by epoch/player/match-or-attempt ID, including retries under a
new producer event ID. Conflicting facts fail. Progress uses verified occurrence
time, so delayed events never spill into the next day. Future events retry.
There is no grace period for expired claims. No client endpoint accepts progress
or rewards. The legacy Nectar stream does not also advance scheduled quests.

Claims require an active player session and `progression:claim`; reads require
`economy:read`. Service facts require `economy:produce`. Claims and the final
weekly bonus use the immutable ledger, in one transaction, under the epoch lock.
Honey/Nectar capability gates still apply. Claims are idempotent across retries,
restarts and cycle rollover. An old economy epoch cannot issue new rewards.

The local UI is available from Warpath's **Quests** button. It displays current
objectives, rewards, reset times, claims and the weekly checklist. It only reads
server projections and sends authenticated intents. A successful claim refreshes
the current economy projection, avoiding stale balances from replayed receipts.
The same claim ID is reconstructed across retries and restarts. Failed reads
clear actionable stale quests. No simulation, ownership or combat rules change.

## Local controls

Use a local isolated stack with its normal authentication, economy epoch and
capabilities configured. Nothing in this change alters checked-in deployment flags.

| Process | Explicit local setting |
|---|---|
| Rank | `RANK_ENABLE_QUESTS=true`, `RANK_QUEST_STARTS_AT=<UTC ISO cutover>` |
| VS worker/proxy | Existing platform delivery enabled, `VS_ENABLE_QUEST_DELIVERY=true`, `VS_QUEST_STARTS_AT=<same UTC ISO cutover>` |
| Debug Godot client | `SF_ENABLE_QUESTS=1` |

Enabled services require an explicit cutover. The VS kill switch also prevents
leasing previously queued quest deliveries. Rank's disabled state refuses new
activity and claim writes. Normal economy delivery flags and rollout restrictions
still apply. The client entry point requires both a debug build and its local flag.
Do not enable these controls on beta until separately authorized.

## Repeatable checks

Run from the project root:

```sh
npm run build --prefix tools/rank-service
npm run smoke:platform-economy --prefix tools/rank-service
npm run smoke:account-deletion --prefix tools/rank-service
npm run smoke:quarantine --prefix tools/rank-service
npm run build --prefix tools/vs-service
npm run smoke:platform-economy --prefix tools/vs-service
npm run smoke:public-contests --prefix tools/vs-service
npm run smoke:public-async-cohorts --prefix tools/vs-service
npm run smoke:quests-http --prefix tools/vs-service
npm run smoke:quarantine --prefix tools/vs-service
python3 tools/run_quest_panel_smoke.py --godot /usr/local/bin/godot
```

The database smokes use disposable embedded PostgreSQL (PGlite). The panel wrapper
creates a temporary minimal project without player autoloads or network access.
The HTTP proxy test uses loopback servers and test keys.

Verified cases include all 28 definitions, all 24 daily templates in rotation,
full-week frozen assignments, 9 simulated weeks, 1,493 activity events, 225 claims,
retry/restart safety, capped progress, separate Free Roll/extra-entry counting,
two distinct Gauntlet runs, natural defeat versus abandonment, canonical live
modes, complete async map sets, cutover/roster boundaries, disabled worker leasing,
unauthenticated/wrong-scope/identity-mismatched HTTP requests, discarded client
reward fields, claim/bonus rollback, missed days, and ledger reconciliation.
Expected full-week payout is 8,140 centi-Honey and 1,640,000 milli-Nectar.

## Remaining release validation

This is a deterministic simulated soak and headless UI smoke, not a human pacing
study or concurrent load test against production PostgreSQL. All participating
modes and contest packs must be available in the eventual rollout environment.
Automatic quest substitutions and publication of daily public contests are not
implemented; existing weekly/monthly/seasonal contests and rolling async support
the flexible three-map requirement. Human timing is still needed to validate the
30–60 minute daily and 4–5 hour weekly targets. No beta rollout is authorized.
