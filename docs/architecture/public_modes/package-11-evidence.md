# Package 11 Evidence Report — Multi-Seat Synchronized Modes

Program mapping: Sharpened readiness Program Package 11; code-grounded execution revision Package 12  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- `STANDARD_3P_FFA`, `STANDARD_2V2`, and `STANDARD_4P_FFA` now use the
  authenticated roster-v2 durable queue, command stream, reconnect, and signed
  verifier path instead of the process-memory quick queue.
- Migration `010_public_multiseat.sql` authorizes the three queue modes and adds
  server-owned competitive identity snapshots, verified friend edges,
  per-peer stream acknowledgements, immutable per-player match history, and
  multi-seat shadow-result storage.
- 3P FFA freezes three unique authenticated players, seats, colors, and team
  identities. 4P FFA does the same for four players.
- 2v2 freezes `FRIEND_THEN_RANK_V1` assignment evidence in the contract:
  exactly one server-verified friend pair stays together; zero or multiple
  candidate pairs rank-sort by descending rank and UUID tie-break, then assign
  highest+lowest against the middle two.
- Rank and friend inputs cannot come from a player request. An admin-authenticated
  identity-sync action populates the durable server snapshot used at formation.
- Multi-seat queue formation is transactional and requires managed PostgreSQL.
  The memory adapter rejects these modes rather than presenting itself as a
  public-capable store.
- Every peer reads the same canonical stream and advances its own durable
  acknowledgement. Reconnect restores the original seat, team, epoch, and
  contract after repository restart.
- Verification accepts two- through four-player human contracts. FFA requires
  one unique player per ordered placement; 2v2 requires two complete team
  placement groups and a matching winning team. Duplicate or missing exclusive
  placements fail closed.
- A verified result writes the same signed receipt for every participant,
  per-player history, and a shadow analytics record. These initial modes create
  no rank settlement, Wax escrow, money payout, or other reward mutation.
- The Godot client accepts and validates complete 3/4-seat contracts, uses the
  durable queue when authenticated, preserves server team/color assignments,
  submits a terminal report from every peer, and polls for the signed outcome.
- `VS_ENABLE_PUBLIC_3P_FFA`, `VS_ENABLE_PUBLIC_2V2`, and
  `VS_ENABLE_PUBLIC_4P_FFA` are independent and default false.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–010 under embedded PostgreSQL: `PASS`.
- Durable multi-seat smoke: `PASS`.
  - 3P/2v2/4P formation with complete identical roster views for every player.
  - Unique seats/colors and FFA teams.
  - Exact-friend-pair and multiple-pair rank-fallback 2v2 branches.
  - Eleven per-peer acknowledgement rows across verified matches.
  - Conflicting client state hashes routed through replay authority.
  - Duplicate exclusive placement rejection and valid signed 3P, 2v2, and 4P
    terminal results.
  - Eleven per-player history rows, three shadow records, and identical signed
    result receipts for all participants.
  - Four-player disconnect/restart/resume with the original seat restored.
  - Zero rank-settlement jobs and zero Crucible escrows.
- Existing durable 1v1, verification, Standard 1v1 release, player-auth,
  quarantine, and full VS smokes: `PASS`.
- Godot durable-contract, non-1v1 multiplayer, human PvP boot, and PvP map
  contract smokes: `PASS`.

## Deliberate release gates

- No environment was migrated and none of the three mode flags was enabled.
- Three- and four-device physical runs, iOS/Android mixed-platform runs, network
  transition/background/termination tests, managed PostgreSQL service-restart
  tests, and the production replay worker remain required before public release.
- The broader `map_mode_contract_smoke_test.gd` currently stops on the existing
  future Corkscrew fixture (`opening_lane_unavailable`). That unrelated map-data
  failure predates this package; the focused PvP map contract smoke passes.

## Rollback

- Keep the three mode flags false. Preserve migration 010, match history, and
  signed shadow results for audit. Revert the package commit to return the UI to
  its legacy internal queue without deleting durable contracts.

## Proposed next package

Implement Package 12: authenticated versioned remote configuration, rollback,
minimum-client enforcement, effective-config diagnostics, independent client
mode gating, and rollout/reconciliation operations.
