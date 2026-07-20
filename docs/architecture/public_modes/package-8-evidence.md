# Package 8 Evidence Report — Time Puzzles and Weekly Gauntlet

Program mapping: Sharpened readiness Program Package 8; code-grounded execution revision Package 9  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- The Free Roll weekly, monthly, and season buttons now open a Dash-native
  public-contest panel. It exposes separate 3-map, 5-map, and weekly Gauntlet
  views, reads only `SERVER_PUBLIC_CONTEST_STORE`, and leaves the old
  full-screen `TimePuzzleLobby` as a paid/legacy adapter.
- `PublicContestState` is a server-only public-board adapter. It never imports
  `ContestState`, `.tres` definitions, `runtime_leaderboards`, or `user://`
  scores. Failed evidence submissions may be retained locally for retry, but
  those files have no board-ingestion path.
- `public_contest_catalog_export.gd` exports the actual five-map sequence and
  current 18-stage progressive plan. The reusable client validator re-hashes
  every map before entry and refuses a server definition whose pack, order,
  occurrence hash, or Gauntlet plan differs from the installed build.
- The frozen catalog hashes for this tree are:
  - 3-map Time Puzzle: `d782b8e08089729e0d5d171588b0933eaf6600004a7beff465f5bef698b49172`
  - 5-map Time Puzzle: `b8a73d7ed4e297d75e01c01fd40c94722e22eaf670c5dbab7fcc6ce8f08eedd2`
  - 18-stage Gauntlet: `340254dba98b6fab355070c1bf0e30ef383293ca79e5bd2a50bc148281d6400e`
- `publish_public_time_gauntlet_periods` accepts an exported catalog plus
  explicit weekly/monthly/seasonal UTC windows. It publishes six independent
  Time Puzzle definitions and one weekly Gauntlet definition. These product
  definitions do not infer calendar boundaries or use fixed-interval rollover,
  so closed historical boards keep their IDs while ops publishes the next
  explicit period.
- Time Puzzle definitions freeze 100 ms ticks, ordered 3/5 map occurrences,
  map hashes, simulation build, complete-run qualification, and
  `TIME_TOTAL_V1`. Gauntlet freezes all 18 stage maps, difficulty/scaling data,
  star thresholds, plan hash, and `GAUNTLET_STARS_V1`.
- Migration `007_time_gauntlet_evidence.sql` adds a durable player-evidence
  queue with idempotent submission, expiring worker leases, verified/rejected
  terminal states, retry-safe result references, and recipient-bound status.
  A player submission cannot update a public result or leaderboard.
- The verifier-worker API leases evidence and may complete it only through the
  trusted server result path. The server re-derives Time Puzzle completion and
  aggregate ticks, and re-derives Gauntlet stars, beaten-stage count, and total
  ticks from ordered stage evidence and the frozen plan.
- Runtime launch metadata carries the server-issued contest/attempt,
  definition/grant hashes, exact map order, and deadline. Terminal Time Puzzle
  and Gauntlet paths submit per-map/stage evidence. Public runs bypass the
  legacy local leaderboard writer.
- Rank identity sessions now mint both `match:queue` and least-privilege
  `contest:play`. Rank migration `006_public_contest_scope.sql` adds the latter
  to still-active, unrevoked sessions so the Dash can issue attempts without
  granting any rank/economy/service mutation scope.
- `VS_ENABLE_PUBLIC_TIME_PUZZLES` and `VS_ENABLE_PUBLIC_GAUNTLET` are independent
  gates beneath `VS_ENABLE_PUBLIC_CONTESTS`; all default false. Health reports
  them without exposing secrets.

## Comparator and leaderboard rules

- Time Puzzle qualifies only an ordered, complete map pack. Competitive order
  is aggregate elapsed ticks ascending, then qualified time, then player UUID.
- Gauntlet stars are derived from the frozen per-stage thresholds. Competitive
  order is stars descending, beaten stages descending, elapsed ticks ascending,
  then qualified time and player UUID.
- Best results remain a unique `(contest_id, player_id)` projection. Multiple
  immutable qualified attempts therefore cannot create multiple public rows.
- A shared JSON golden file is executed by both GDScript and TypeScript. It
  covers complete Time Puzzle aggregation, three Gauntlet wins across star
  thresholds, and a terminal Gauntlet loss.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–007 under embedded PostgreSQL: `PASS`.
- Public contest backend smoke: `PASS`.
  - Seven explicit period definitions were built: 3/5-map weekly, monthly, and
    seasonal Time Puzzles plus weekly Gauntlet.
  - Shared comparator golden cases matched exactly.
  - Player evidence remained non-public until a leased worker committed a
    trusted result; replaying the evidence submission was idempotent.
  - Period close held in `FINALIZING` while pre-deadline evidence was leased,
    then froze placement after the worker resolved it.
  - The verified result projected exactly one best-player row.
  - Historical rollover/platform recovery, two-repository board parity,
    restart persistence, outbox delivery, and local-fixture isolation remained
    green after migration 007.
- Godot comparator smoke: `PASS`.
- Godot catalog, exact-hash, 18-stage plan, Dash navigation, and local-board
  isolation smoke: `PASS`.
- Main Menu money-contest routing/layout regression: `PASS`.
- Existing non-1v1 and durable 1v1 handshake regressions: `PASS`.
- Rank identity build, token, embedded session/restart, verified settlement,
  and economy-quarantine regressions after migration 006: `PASS`.
- Existing headless asset parsing emits known NUL-character map warnings, and
  the menu smoke emits existing headless shader warnings; both tests exit zero.

Embedded durable proof counts after the worker-boundary test:

- 3 contest generations and 3 real roster entrants.
- 4 server-issued attempts and 4 immutable trusted results.
- 3 best-player rows, 3 historical placements, and 9 contest receipts.
- 3 durable top-placement messages.

## Deliberate boundaries and release gates

- No environment was migrated, no catalog periods were posted, and no feature
  flag was enabled.
- The leased contest verifier endpoint is implemented and tested, but a
  production contest replay worker/artifact manifest has not been deployed or
  certified against real Time Puzzle/Gauntlet command streams. Unprocessed
  evidence remains `PENDING` and cannot affect standings.
- Two-device staging, service restart with managed PostgreSQL, explicit period
  publication, backup/restore, load/rate-limit testing, and winner-message
  delivery must pass before either family flag is enabled.
- No rank, Wax, cash, or badge side effect is attached to these contests.

## Rollback

- Keep `VS_ENABLE_PUBLIC_TIME_PUZZLES=false` and
  `VS_ENABLE_PUBLIC_GAUNTLET=false`; the parent contest gate may remain false as
  well.
- Preserve migration 007 and queued evidence for audit/replay. Do not project
  client evidence or restore local leaderboards as a public fallback.
- The paid/legacy lobby adapter remains available independently of these public
  family flags.

## Proposed next package

Implement Package 9, Crucible settlement correction: exact 1000/1000 Wax-millis
escrow, 1800 winner payout, auditable 200 reserve contribution, full refunds,
PostgreSQL receipts/reversals, ops reserve metrics, and independent settlement
and public-mode gates.
