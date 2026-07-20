# Swarmfront Public Modes Readiness Program — Code-Grounded Revision

Date: 2026-07-18

This revision turns the broader readiness program into bounded work packages aligned with the current Swarmfront codebase. It does not authorize any public flag, economy mutation, or deployment.

## 1. Current architecture baseline

The program must begin from these facts:

1. `tools/vs-service/src/server.ts` owns matchmaking records and canonical command ordering, but not gameplay simulation. It stores sessions as `host` plus `guest`, sequences submitted commands, and rebases their execution ticks.
2. `scripts/state/vs_pvp_runtime.gd` runs the deterministic match locally through `OpsState`, publishes commands and state hashes, and currently models one local and one remote peer even though parts of its roster parsing understand seats 1–4.
3. The VS service accepts client-supplied player IDs for normal matchmaking calls. It has admin and match-authority secrets for privileged economy calls, but it does not authenticate ordinary players as the ENTaP identity they claim.
4. The rank service uses PostgreSQL, but most rank actions require one static bearer token. The Godot client is presently designed to hold that token directly. A shared service secret must not be shipped in a public client.
5. VS sessions, queues, intent streams, `MoneyLedger`, async results, and payout reports are in-memory maps. A service restart loses them. Crucible and Honey have file-backed adapters explicitly described as development adapters.
6. `VsLobby` caps synchronized sessions at two players. Its async window fills visible slots with placeholder names.
7. `ContestState` stores runtime leaderboards under `user://`; those boards are local fixtures, not public leaderboards.
8. Bundled contest resources are static `.tres` fixtures such as `WEEKLY_FREE_0_2025-W52`, not server-created weekly/monthly/seasonal instances.
9. Standard synchronized rank settlement accepts one player and one opponent. It cannot represent three-player placements, four-player placements, or team outcomes.
10. The bundled operations config has no remote URL, disables paid entries, and disables the rank backend.

These are release blockers, not cleanup items.

## 2. Decisions to freeze before implementation

The following recommended product contracts are narrow enough to implement against the current code. Any different decision should be made before its schema work starts.

### 2.1 Authority model

Use two explicit authority tiers:

- `RELAY_ATTESTED`: The VS server owns roster and canonical command order. All clients run the deterministic simulation and submit terminal state hashes. Matching results may be used for internal/unranked testing; conflicts become `NO_CONTEST` and enter review.
- `AUTHORITY_VERIFIED`: A trusted headless Godot match worker consumes the canonical command stream, reproduces the terminal state, and signs the result receipt. Ranked or economic matches require this tier.

The repository already has canonical command sequencing, state hashes, authority snapshots, and a match-authority token boundary. Extending those pieces is substantially smaller and safer than pretending the current Node relay already determines the winner.

Public ranked 1v1 and Crucible require `AUTHORITY_VERIFIED`. Unranked closed beta modes may use `RELAY_ATTESTED` only if the product explicitly accepts its abuse limits.

### 2.2 Mode policies

| Mode | Initial rank policy | Economy | Buff policy | Public board |
|---|---|---|---|---|
| Standard 1v1 | Global Rank | Existing normal Wax policy only after authority is verified | Standard | Global Rank |
| Crucible | No ordinary Rank award | 1.0 Wax each; 1.8 winner; 0.2 award reserve | Disabled | No dedicated board required for first release |
| 3P FFA | Unranked; shadow analytics | None | Inherit Standard unless changed explicitly | None initially |
| 2v2 | Unranked; shadow team analytics | None | Inherit Standard unless changed explicitly | None initially |
| 4P FFA | Unranked; shadow analytics | None | Inherit Standard unless changed explicitly | None initially |
| Human CTF/HCTF | Product decision still required; recommend unranked first | None | CTF ruleset | Optional later |
| Bot CTF/HCTF | Practice/no-rank | None | CTF ruleset | Never included with humans |
| Time Puzzles | Contest placement only | None initially | Contest contract | Weekly/monthly/seasonal |
| Gauntlet | Contest placement only | None initially | Progressive rules | Weekly |
| Async 3/5 map | Contest placement only | No payout until separately approved | Contest contract | Per contest cohort |

“Top three winners are messaged” does not imply that the top three are paid. Notifications and reward schedules are separate contracts.

### 2.3 Time and contest comparators

- Time Puzzle qualification: all maps in the selected 3-map or 5-map pack must be completed. Incomplete runs remain telemetry but do not appear on the public board.
- Time Puzzle order: aggregate authoritative time ascending, earliest qualified submission, stable player ID.
- Best-result policy: one best qualified result per player per contest and map-pack version.
- Gauntlet order: stars descending, completed stages descending, authoritative elapsed time ascending, earliest qualified submission, stable player ID.
- Async 3/5-map order: use the versioned Time Puzzle comparator unless the mode is intentionally different.
- Canonical scope names: `WEEKLY`, `MONTHLY`, `SEASONAL`. Accept current `YEARLY` only as a migration alias.

### 2.4 Async four-player lifecycle

Use different policies for free and economic contests:

- Free contest: a server-created cohort may accept attempts immediately and close atomically on four distinct qualified players. It stores each player’s best result under the disclosed attempt policy.
- Economic contest: lock four real entrants before play, escrow exactly once, enforce one scored attempt per entrant, and finalize when all four are terminal or the deadline applies DNF.

For the first implementation, make the 3-map and 5-map versions free. Add money only after the free lifecycle, leaderboard, closure, and outbox have production evidence.

## 3. Actual ownership map

| Concern | Current code | Required destination |
|---|---|---|
| Matchmaking/session | `tools/vs-service/src/server.ts` | Durable VS PostgreSQL store with roster v2 |
| Godot matchmaking client | `scripts/state/vs_handshake_state.gd`, `scripts/ui/vs_lobby.gd` | Authenticated roster/contract consumer |
| Command transport | `scripts/state/vs_pvp_runtime.gd`, VS `publish_intent`/`poll_intents` | Durable canonical stream plus authority worker |
| Simulation | `OpsState`, Arena, `VsPvpRuntime` | Headless Godot verifier for ranked/economic results |
| Rank | `tools/rank-service`, `RankState`, `RankRuntimeAwards` | Server-to-server mutation; public read API |
| Local contests | `ContestState`, `.tres` definitions | Development fixtures only |
| Public contests/boards | Partial VS `contestDash` and `MoneyLedger` | Durable non-economic contest store and read API |
| Crucible | `crucibleLedger.ts`, `CrucibleState` | Durable award-reserve settlement |
| Async money | `moneyLedger.ts` | PostgreSQL-backed ledger only after free lifecycle proof |
| Operations flags | `OpsConfig`, bundled JSON | Remote config with per-mode gates |
| Result messages | None | Durable server outbox plus Dash inbox |

## 4. Ordered implementation work packages

Each package is intentionally bounded. Do not combine adjacent packages into one approval.

### Package 0 — Contract and authority ADRs

Deliver:

- Mode policy registry covering rank, buffs, bots, disconnects, attempts, leaderboards, and rewards.
- ADR for `RELAY_ATTESTED` versus `AUTHORITY_VERIFIED`.
- Roster v2 schema.
- Canonical sync-result v1 schema.
- Contest lifecycle v1 schema.
- Comparator registry v1.
- Idempotency key namespace registry.

Important schema choices:

- Use the existing internal UUIDv7 as `player_id`; treat the formatted ENTaP ID as a public display identifier, not a primary key.
- Use `map_id` plus a content SHA-256. Current map IDs alone are not immutable content versions.
- Use a server-stored `contract_hash`. A detached client-verifiable signature can be added when offline verification is needed; HTTPS plus authenticated server retrieval is sufficient for the first online contract.

Exit: no unresolved decision can change roster, result, or contest database keys.

### Package 1 — Player authentication and service trust

This is the first code package and a blocker for every public mode.

Implement:

- An ENTaP session credential issued by the identity service after authenticated account creation/resume.
- Short-lived player access tokens and revocable refresh/device credentials.
- VS middleware that derives `player_id` from the verified token and rejects a conflicting body `uid`.
- Rank public reads authenticated as the player or explicitly public; rank mutations accepted only server-to-server.
- Remove the design in which the exported Godot client contains `RANK_API_TOKEN`, `VS_MATCH_AUTHORITY_TOKEN`, or an equivalent shared secret.
- Bind invite, ready, command, result, contest-entry, and outbox-ack actions to the authenticated player.

Likely files:

- `tools/rank-service/src/server.ts` and new identity-session migrations.
- `tools/vs-service/src/server.ts` and authentication middleware.
- `scripts/profile/profile_manager.gd` for token/session lifecycle.
- `scripts/state/vs_handshake_transport_http.gd` and `rank_transport_http.gd`.

Exit:

- Player A cannot act as Player B by changing JSON.
- A leaked player token cannot invoke admin or match-authority actions.
- No service credential is present in an exported client.

### Package 2 — Durable VS state and idempotency

Add PostgreSQL and migrations to `tools/vs-service`; it currently has none.

Persist at minimum:

- Match/session contracts.
- Roster entries and readiness.
- Reconnect epochs and disconnect state.
- Canonical command events or a durable event-log reference.
- Terminal result receipts.
- Idempotency receipts.
- Contest definitions, cohorts, entries, attempts, results, rankings, and closure state.
- Outbox messages.
- Economic transactions and settlement receipts before any economic flag is enabled.

Keep in-memory maps only as test adapters. File-backed Crucible/Honey stores remain development adapters.

Exit:

- Restarting the VS process does not lose an active contract, accepted result, contest entry, leaderboard row, outbox message, or economic receipt.
- Repeating a completed write after restart returns the original receipt.

### Package 3 — Roster v2 on the existing two-player flow

Do not start with 3P/4P gameplay. Migrate 1v1 first.

Server changes:

- Replace `host`/`guest` as the canonical model with `roster[]` and `required_players`.
- Retain derived `host`/`guest` fields temporarily for compatibility.
- Server assigns seat, team, and color; the client may express accessibility preferences but not final allocation.
- Ready/start checks iterate the roster.
- Invite and quick-match flows create the same contract shape.

Godot changes:

- `VsHandshakeState` normalizes `roster[]`.
- `VsLobby` renders real roster entries and never invents synchronized players.
- `VsPvpRuntime` replaces singular `_remote_uid/_remote_seat` assumptions with peer collections, while preserving a two-player convenience accessor during migration.
- Shell/Arena consume the contract roster instead of display-name arrays.

Exit:

- Existing local 1v1 smokes still pass through the compatibility adapter.
- Two authenticated clients receive the same two-seat contract.
- A synthetic 3/4-seat server contract validates even though those modes remain disabled.

### Package 4 — Result authority and rank settlement

Build the missing trusted result path.

Implement:

- A headless Godot authority worker that consumes the roster, rules/map hash, and canonical command stream.
- A canonical terminal result receipt containing ordered placements, terminal reason, elapsed simulation time, final state hash, authority epoch, and contract hash.
- Conflict handling: no-contest/review, never client-selected settlement.
- Server-to-server rank mutation using the verified receipt and a stable event ID.
- Reconnect grace and authority-issued forfeit.
- Pending settlement state when rank is unavailable.

Do not generalize rank formulas here. Support only two-player Standard 1v1.

Exit:

- Duplicate terminal submissions produce one receipt and one rank mutation.
- A modified client winner, stale epoch, wrong map hash, or conflicting state hash is rejected.
- App termination/reopen can retrieve the existing result and settlement state.

### Package 5 — Standard 1v1 release candidate

Wire:

- Remote flags `enable_public_1v1` and `enable_rank_mutations`, both false by default.
- Global Rank as the only initial synchronized public board.
- Public leaderboard fail-closed behavior with explicit cached/stale labels.
- Two-device reconnect, forfeit, and result recovery UI.

Exit: Standard 1v1 passes the full staging physical-device matrix and can be reviewed independently for beta rollout.

### Package 6 — Human CTF/HCTF and bot fallback

Reuse the certified two-seat roster and result path.

Implement:

- Route Human CTF/HCTF from `_on_human_mode_selected` into `VsLobby`, not `_launch_direct_capture_flag`.
- Carry CTF rules and map hash in the server contract.
- Preserve `_launch_direct_capture_flag` only behind explicit bot choices.
- After the approved search threshold, offer continue/search, selected-mode bot, or cancel.
- Use canonical server-recognized bot IDs and mark the contract `practice=true`, `ranked=false`, `economic=false`.
- Block `RankRuntimeAwards` for bot/practice contexts.

HCTF security gate:

- Before public HCTF, verify the opposing client cannot inspect the hidden flag through packets, scene metadata, logs, replay data, or predictable seeds.
- If the current client must receive the hidden location to simulate the game, HCTF remains internal until the authority worker can withhold it.

Exit: Human buttons always search for humans first; bot diversion is explicit and never ranked.

### Package 7 — Non-economic public contest platform

Create a durable contest service before editing Dash.

Implement APIs for:

- Fetch current contest definitions by family/scope/map count.
- Enter a free contest and issue an attempt ID.
- Submit an idempotent result.
- Compare and preserve the best result per player.
- Fetch a versioned public leaderboard.
- Close/roll contests using server time.
- Read and acknowledge result outbox messages.

Do not use `MoneyLedger` as the foundation for free contests; it currently requires an escrow pot. Build a non-economic contest store and let future economic settlement reference it.

Treat the current `.tres` contest resources and `ContestState.runtime_leaderboards` as local/dev fixtures. Never merge them into a public board response.

Exit:

- Two devices see the same server board.
- A VS restart preserves the board and idempotency receipts.
- Local files cannot impersonate public data.

### Package 8 — Time Puzzles and Gauntlet

Time Puzzles:

- Add Dash navigation for weekly/monthly/seasonal and 3/5-map variants.
- Replace the full-screen `TimePuzzleLobby` as the primary route; it may remain a temporary adapter.
- Submit per-map and aggregate authoritative elapsed times.
- Server applies complete-run qualification and best-per-player deduplication.

Gauntlet:

- Publish a weekly server contest and require contest/attempt IDs for public runs.
- Freeze the 18-stage plan by content hash.
- Submit terminal stars, completed stages, elapsed time, and stage evidence.
- Implement the current local comparator on the server.
- Deduplicate by player before assigning rank.

Exit:

- Weekly/monthly/seasonal rollover retains historical boards.
- Gauntlet and Time Puzzle boards reproduce expected local comparator fixtures exactly.
- Only a player’s best qualified result occupies a public position.

### Package 9 — Crucible settlement correction

Modify both `crucibleLedger.ts` and the GDScript preview path:

- Stake each: `1000` Wax millis.
- Winner payout: `1800`.
- Award-reserve contribution: `200`.
- Cancellation refund: `1000` to each participant.
- Replace `crucible_burn` semantics with an auditable award-reserve account.
- Persist transaction, escrow, refund, settlement, reserve, reversal, and idempotency receipts in PostgreSQL.
- Expose reserve metrics to ops, not necessarily to the player Dash in this package.
- Repair the stale Crucible ruleset smoke that expects a removed `EconomyBuffState` autoload.

Crucible may reuse the certified 1v1 roster and authority worker. It must not reuse ordinary rank settlement.

Exit:

- Exact 1000/1000/1800/200 accounting and restart recovery pass.
- No client path can settle or redirect the reserve.
- `enable_public_crucible` and `enable_crucible_wax_settlement` remain independently false until approved.

### Package 10 — Free async 3-map and 5-map cohorts

Build on Package 7:

- Separate family/version IDs for 3-map and 5-map cohorts.
- Four real authenticated identities; no placeholder names.
- Atomic closure on the fourth distinct qualified result for the initial free policy.
- Best-result behavior follows the frozen attempt policy.
- Snapshot top three placements.
- Write placement messages to all four entrants, with top-three copy where appropriate.
- No payout schedule in the first release.

Only after this is stable should an economic variant add locked rosters, escrow, DNF deadlines, refunds, and a separately approved payout schedule.

Exit:

- Concurrent fourth submissions close once.
- Worse retries do not replace better rows.
- 3-map and 5-map cohorts never cross-contaminate.
- Outbox messages are idempotent and recoverable after restart.

### Package 11 — 3P FFA, 2v2, and 4P FFA

Complete the multi-peer runtime only after roster v2 and two-player authority are stable.

Shared work:

- Multi-peer command polling, acknowledgements, state-hash quorum, reconnect, and terminal result handling.
- Three/four-placement result validation.
- Per-seat match history and shadow analytics.

3P FFA:

- Three unique seats/teams/colors and three ordered placements.

2v2:

- Exactly one valid friend/party pair is preserved.
- With zero pairs or conflicting multiple pairs, rank-sort and assign highest+lowest versus the two middle players.
- Store the immutable final team map in the contract.
- Result contains one winning team and per-player placement/history.

4P FFA:

- Four unique seats/teams/colors and four ordered placements.
- Define eliminated-player leave/spectate behavior before implementation.

All three begin unranked and non-economic.

Exit: physical three/four-device tests pass; no normal rank or currency changes occur.

### Package 12 — Operations and controlled rollout

Add remote flags using the repository’s existing lowercase style:

- `enable_public_1v1`
- `enable_public_crucible`
- `enable_public_3p_ffa`
- `enable_public_2v2`
- `enable_public_4p_ffa`
- `enable_public_ctf`
- `enable_public_hctf`
- `enable_public_time_puzzles`
- `enable_public_gauntlet`
- `enable_public_async_3map`
- `enable_public_async_5map`
- `enable_rank_mutations`
- `enable_crucible_wax_settlement`
- `enable_contest_rewards`
- `enable_bot_fallback`
- `enable_public_leaderboards`

Update `OpsConfig` normalization, defaults, remote sample, menu gating, and support diagnostics. Every new flag defaults false.

The bundled `ops_config/remote_url` is currently empty. A signed or authenticated remote config publication path and rollback history are prerequisites for relying on these flags operationally.

## 5. Mode release order

Use this dependency order rather than three large release trains:

1. Identity/auth and durable VS state.
2. Roster v2 on existing 1v1.
3. Trusted result authority and server-to-server rank settlement.
4. Standard 1v1 internal certification.
5. Human CTF/HCTF and explicit bot fallback.
6. Free public contest platform.
7. Time Puzzles and weekly Gauntlet.
8. Crucible accounting and settlement.
9. Free async 3/5-map cohorts and outbox.
10. Economic async variants, only if separately approved.
11. 3P FFA, 2v2, and 4P FFA.
12. Mode-by-mode rollout.

This order proves authentication, persistence, authority, and public reads before adding economy or multi-peer complexity.

## 6. Test and evidence gates

### Required automated layers

- VS TypeScript build and smoke: `npm run build`, `npm run smoke`, `npm run smoke:quarantine`, `npm run smoke:spectator` in `tools/vs-service`.
- Rank build/migrations/smokes in `tools/rank-service`.
- Godot headless contract tests for each changed route.
- PostgreSQL migration-up, restart-recovery, and rollback tests.
- Idempotency tests repeated across process restarts.
- Comparator golden fixtures shared between GDScript and TypeScript.
- Authority-worker deterministic replay and conflict tests.

### Required device gates

- iOS/iOS, Android/Android, and iOS/Android.
- Wi-Fi/cellular transitions.
- Background/foreground.
- Terminate/reopen.
- Disconnect inside/outside grace.
- Service restart during search, active match, result submission, contest closure, and settlement.
- Three/four-device matrix for multi-seat modes.

### Required operational evidence

- Mode flag and mutation flag states.
- Contract/result/contest/outbox IDs visible to support.
- Search, reconnect, desync, no-contest, result, leaderboard, escrow, reserve, refund, and closure metrics.
- Alert thresholds and one exercised rollback per released mode.
- Explicit recommendation: `HOLD`, `INTERNAL ONLY`, `BETA`, or `PUBLIC READY`.

## 7. Alignment amendments

These two rules preserve the product owner's original mode definitions when they differ from later planning language:

1. Free async 3-map and 5-map contests do not wait in a locked lobby for four entrants before anyone can play. They remain open until four distinct authenticated players have submitted qualified results, then close atomically. Locked-before-play rosters are reserved for future economic contests.
2. In 2v2, exactly one valid friend/party pair is preserved. If there are zero or multiple candidate pairs, ignore friend pairing and apply the specified rank balance: highest plus lowest versus the two middle players.

## 8. Repository-shape amendments

- `docs/pvp_authority_audit.md` correctly names `OpsState`/`SimState` as the sole gameplay-state mutation authority inside a running simulation. The public-modes program adds a separate trust boundary: ranked/economic receipts must come from a trusted headless instance of that same simulation, not a player-controlled instance.
- `docs/sf_entap_bridge_plan.md` allows local identity for offline/dev launch. That remains valid for offline/dev surfaces, but public competitive endpoints require an authenticated backend UUID session and supersede the older local-identity assumption for those endpoints only.
- Keep the historical `tools/rank-service` directory name during the authentication vertical slice. Package 0 must decide whether it remains the identity-session issuer or is split later; do not rename it as incidental cleanup.
- Add the trusted Godot verifier as a separate service boundary, tentatively `tools/match-authority`, rather than embedding Godot process management into `tools/vs-service/src/server.ts`.
- Add VS persistence through repository interfaces and VS-owned migrations. Do not couple VS tables directly to the rank service's store merely because that service already uses PostgreSQL.
- Keep the high-frequency canonical command stream behind its own storage adapter and ADR. Match/contest relational persistence does not automatically imply one synchronous SQL insert per gameplay command.

## 9. Immediate next implementation slice

Do not start with roster generalization, mode buttons, or authentication code before the authority decisions are frozen.

The next bounded slice is Package 0. It should decide and document:

1. Which component issues and revokes the authenticated UUIDv7 player session.
2. Which credential proves identity after onboarding and account resume.
3. How that credential is securely stored and restored on iOS and Android.
4. How player, public-read, match-authority, service-to-service, and administrative endpoints are classified.
5. Which durable command-stream and restart policy supports the verifier.

After those decisions are accepted, Package 1 authenticates one Standard 1v1 queue action end to end, derives the player from the verified session, rejects a conflicting body identity, and proves that the credential cannot invoke privileged operations.

Until Package 1 passes, every public mode remains `HOLD`, even if its local gameplay smoke tests pass.
