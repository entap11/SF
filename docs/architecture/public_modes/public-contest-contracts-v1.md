# Public Contest Contracts v1

Status: Frozen for implementation
Date: 2026-07-18

This contract covers Weekly/Monthly/Seasonal timed puzzles, Weekly Gauntlet, and free rolling async 3-map/5-map cohorts. Paid async contests are not authorized by this version.

## 1. Contest definition

| Field | Type | Rule |
|---|---|---|
| `contest_id` | UUID | Immutable contest or rolling cohort identity |
| `contest_schema_version` | integer | `1` |
| `family` | enum | `TIME_PUZZLE`, `GAUNTLET`, `ASYNC_MAP_SET` |
| `scope` | enum | `WEEKLY`, `MONTHLY`, `SEASONAL`, `ROLLING_COHORT` |
| `status` | enum | Lifecycle below |
| `map_pack_id`, `map_ids` | string/list | Server-published content |
| `content_hashes` | object | Exact map/rule/sim hashes |
| `sim_build_id` | string | Required verification artifact |
| `comparator_id` | string | Registry entry; immutable after open |
| `best_entry_policy` | enum | `BEST_PER_PLAYER` or `ONLY_SCORED_ATTEMPT` |
| `attempt_policy` | object | Scored-attempt limits and replacement rules |
| `closure_policy` | object | Time period or distinct-qualified-player threshold |
| `eligibility_policy` | object | Authentication/build/rules requirements |
| `starts_at`, `ends_at` | timestamp/null | Server UTC; end required for period boards |
| `created_at`, `opened_at`, `closed_at` | timestamp/null | Server UTC |
| `definition_hash` | SHA-256 | Canonical definition hash |
| `leaderboard_id` | UUID | Published board identity |

Definitions are server-authored and validated against the registries. Client `.tres` resources may render a preview but are not the public definition authority.

## 2. Period-board lifecycle

Timed puzzle and Gauntlet periods use:

`SCHEDULED -> OPEN -> FINALIZING -> CLOSED`

The service uses server time. An attempt must be issued while `OPEN`, and player evidence must satisfy its server-issued submission deadline. `FINALIZING` blocks new attempts but permits trusted workers to finish evidence that the server durably received before the deadline, plus idempotent retries of already committed submissions. Placement freezes only after those jobs reach a verified or rejected terminal state. The board publishes after verification/outbox processing is complete.

Weekly, monthly, and seasonal scopes are distinct contest IDs with explicit UTC boundaries. “Seasonal” is not inferred from a local calendar or client clock.

## 3. Free rolling async lifecycle

Free async 3-map and 5-map contests are rolling four-player cohorts:

`OPEN -> FINALIZING -> CLOSED`

- Play is immediate; the cohort does not wait for four players before issuing an attempt.
- A cohort closes when four distinct authenticated players have committed qualified results.
- Version 1 permits one scored attempt per player per cohort. Network retries are unlimited within the same idempotency key. A server-declared infrastructure failure may void the attempt and issue one replacement grant with an audit event.
- The transaction that commits the fourth distinct qualified player atomically changes the cohort to `FINALIZING`.
- A concurrent fifth distinct player cannot enter the closed cohort. The service assigns that player to the next open cohort before issuing play authority, or returns a retryable cohort-rollover response.
- A player already scored in the cohort cannot occupy another slot through a second device or identity body field.
- `FINALIZING` ranks the four results and emits result messages to the top three; the fourth receives a completion message. Version 1 defines placement messaging, not an economic reward.

The future economic design may require a locked roster before play. It is outside this free-contest contract and must use a new policy/version.

## 4. Attempt and qualified result

The server issues an attempt grant containing:

- `attempt_id`, `contest_id`, `player_id`, and `attempt_number`.
- Definition hash, simulation build, map/rule hashes, and seed(s).
- Issue and submission-deadline timestamps.
- Attempt policy version and signed grant hash.

A qualified result contains:

- Immutable `contest_result_id`, attempt/contest/player IDs, and idempotency key.
- Verification method and trusted evidence reference.
- Per-map completion, elapsed ticks, faults/penalties, and aggregate time where applicable.
- Gauntlet stage count, stars, and elapsed ticks where applicable.
- `qualified_at` server timestamp.
- Definition/content/build hashes.

Player identity is derived from the access token and must match the attempt grant. The server validates evidence; a client score or local `user://` leaderboard is never public authority.

## 5. Best-entry projection

Leaderboard rows are projections, not raw attempt logs. For `BEST_PER_PLAYER`, select exactly one qualified result for each canonical `player_id` using the registered comparator, then rank those selected rows using the same comparator. Thus a player can appear only once even if several attempts would otherwise be in the displayed top N.

Timed puzzle and Gauntlet boards allow unlimited issued attempts during `OPEN`, subject to abuse/rate limits, and retain the best qualified result. Free rolling cohorts use `ONLY_SCORED_ATTEMPT`.

Ties remain deterministically ordered for pagination using the registry tie-breakers. Product UI may display the same ordinal place for exactly equal competitive values even though storage order remains stable.

## 6. Messaging and side effects

Closing a contest writes the close record, final placements, and outbox messages in one transaction. Delivery is at-least-once; message IDs are stable and acknowledgement is idempotent. Failure to deliver a message does not reopen or rerank the contest.

Any future rank, badge, Wax, or cash effect must be a separately versioned idempotent consumer of the immutable contest result. No such reward is authorized in Package 0.
