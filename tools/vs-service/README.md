# Swarmfront VS Service

Minimum VS handshake backend for two-phone TestFlight smoke tests.

This implements the routes in `../../docs/vs_backend_contract.md`. Production Crucible storage/auth is pinned to Supabase Postgres plus Supabase Auth, but the current service still uses local/dev adapters unless those production adapters are wired. Authenticated Standard 1v1 has a complete durable route slice behind disabled-by-default gates; legacy/private routes continue to use their existing adapters.

## Local Run

```bash
cd tools/vs-service
npm install
npm run build
npm run smoke
npm run smoke:quarantine
npm run smoke:durable-core
npm run smoke:durable-1v1
npm run smoke:verification
npm run smoke:standard-1v1-release
npm run smoke:public-rank
npm run smoke:public-contests
npm run dev
```

Local base URL:

```text
http://127.0.0.1:8791/v1
```

## Routes

- `GET /health`
- `GET /v1/health`
- `POST /v1/create_invite`
- `POST /v1/join_invite`
- `POST /v1/get_session`
- `POST /v1/set_ready`
- `POST /v1/can_start`
- `POST /v1/start_session`
- `POST /v1/leave_session`
- `POST /v1/enqueue_quick_match`
- `POST /v1/enqueue_public_1v1`
- `POST /v1/poll_public_1v1`
- `POST /v1/cancel_public_1v1`
- `POST /v1/get_public_bot_fallback_offer`
- `POST /v1/accept_public_bot_fallback`
- `POST /v1/get_public_1v1_session`
- `POST /v1/set_public_1v1_ready`
- `POST /v1/start_public_1v1`
- `POST /v1/publish_public_1v1_command`
- `POST /v1/poll_public_1v1_commands`
- `POST /v1/leave_public_1v1`
- `POST /v1/resume_public_1v1`
- `POST /v1/submit_public_1v1_terminal_report`
- `POST /v1/get_public_1v1_result`
- `POST /v1/get_public_global_rank`
- `POST /v1/list_public_contests`
- `POST /v1/get_public_contest_roster`
- `POST /v1/enter_public_contest` (player token with `contest:play`)
- `POST /v1/submit_public_contest_result` (trusted match authority only)
- `POST /v1/get_public_contest_leaderboard`
- `POST /v1/list_public_contest_messages` (player token with `contest:play`)
- `POST /v1/ack_public_contest_message` (player token with `contest:play`)
- `POST /v1/publish_public_contest` (admin only)
- `POST /v1/reconcile_public_contests` (admin only)
- `POST /v1/lease_match_verification` (verifier worker only)
- `POST /v1/complete_match_verification` (verifier worker only)
- `POST /v1/fail_match_verification` (verifier worker only)
- `POST /v1/poll_quick_match`
- `POST /v1/cancel_quick_match`
- `POST /v1/fill_free_bot_match` (free, non-Crucible sessions only)
- `POST /v1/open_money_escrow`
- `POST /v1/settle_money_match`
- `POST /v1/refund_money_match`
- `POST /v1/open_async_entry_escrow`
- `POST /v1/settle_async_contest`
- `POST /v1/preview_async_contest_payout_report`
- `POST /v1/list_async_contest_payout_reports`
- `POST /v1/approve_async_contest_payout_report`
- `POST /v1/settle_async_contest_payout_percentages`
- `POST /v1/refund_async_entry`
- `POST /v1/get_money_transactions`
- `POST /v1/get_money_payout_summary`
- `POST /v1/get_honey_balance`
- `POST /v1/get_honey_policy`
- `POST /v1/record_honey_activity`
- `POST /v1/grant_honey`
- `POST /v1/debit_honey`
- `POST /v1/preview_hive_honey_purchase`
- `POST /v1/debit_hive_honey_purchase`
- `POST /v1/get_honey_transactions`
- `POST /v1/get_wax_policy`
- `POST /v1/record_competitive_wax_result`
- `POST /v1/publish_intent`
- `POST /v1/poll_intents`
- `POST /v1/create_spectator_grant`
- `POST /v1/join_spectate`
- `POST /v1/poll_spectator_events`
- `POST /v1/publish_spectator_snapshot`
- `POST /v1/poll_spectator_snapshots`
- `POST /v1/leave_spectate`

The same `POST /<action>` routes are also available for hosts that prefer a root base URL.

## Environment

- `PORT`: HTTP port. Defaults to `8791`.
- `BIND_HOST`: bind host. Defaults to `0.0.0.0`.
- `VS_CORS_ENABLED`: defaults to `true`.
- `VS_SESSION_TTL_SEC`: defaults to `900`.
- `VS_QUEUE_TTL_SEC`: defaults to `90`.
- `VS_INTENT_STREAM_MAX_EVENTS`: defaults to `512`.
- `VS_SPECTATOR_ADMIN_TOKEN`: bearer token required to create spectator grants.
- `VS_SPECTATOR_DEV_OPEN`: local/debug-only grant bypass. It is ignored in production and must remain disabled there.
- `VS_SPECTATOR_LIVE_ENABLED`: set to `1` to allow live admin spectate.
- `VS_SPECTATOR_DEFAULT_DELAY_SEC`, `VS_SPECTATOR_MIN_DELAY_SEC`, `VS_SPECTATOR_MAX_DELAY_SEC`: delayed spectator bounds.
- `VS_SPECTATOR_PUBLIC_ENABLED`: keep disabled for beta unless separately reviewed.
- `VS_ADMIN_TOKEN`: admin auth for Crucible config/review/debug endpoints and Honey debug endpoints; required in production.
- `VS_ECONOMY_MUTATIONS_ENABLED`: production economy mutation gate. Defaults to `false`; disabled routes return HTTP 503 with `err=code=economy_disabled`.
- `VS_ECONOMY_RESET_ENABLED`: separate reset gate. Defaults to `false` and has no effect unless the mutation gate is also enabled.
- `VS_ECONOMY_EPOCH`: versioned one-time Honey/Wax ledger reset. Use `beta_2026071301` for this beta release and change it only for an intentional future reset.
- `VS_ADMIN_ROLE`: local/dev expected admin role. Defaults to `ops_admin`.
- `VS_MATCH_AUTHORITY_TOKEN`: match-authority auth for Crucible escrow, settlement, lifecycle writes, Honey grant/debit writes, and competitive Wax result writes; required in production.
- `VS_DURABLE_CORE_ENABLED`: durable repository gate. Defaults to `false`; it does not independently enable public matching.
- `VS_DURABLE_PUBLIC_1V1_ENABLED`: authenticated Standard 1v1 durable-route gate. Defaults to `false` and requires `VS_DURABLE_CORE_ENABLED=true`.
- `VS_ENABLE_PUBLIC_1V1`: release gate for the durable, authority-verified Standard 1v1 route. Defaults to `false`; public enqueue also requires the durable-core, durable-route, and match-verification gates plus `AUTHORITY_VERIFIED` contracts.
- `VS_ENABLE_PUBLIC_CTF`: independent release gate for authenticated, authority-verified, initially unranked human CTF. Its contract uses `CTF_1V1` and freezes the CTF ruleset/map hashes.
- `VS_ENABLE_PUBLIC_HCTF` and `VS_HCTF_LIVE_SECRECY_CERTIFIED`: both must be true for a human HCTF enqueue. The secrecy gate defaults false and must remain false while an opposing client can derive hidden placement.
- `VS_ENABLE_CTF_BOT_FALLBACK`: enables the server-timed CTF/HCTF practice offer. Acceptance cancels the human ticket and creates a distinct `CTF_BOT`/`HCTF_BOT` contract with canonical bot identity, `practice=true`, and no rank/economy policy.
- `VS_ENABLE_RANK_MUTATIONS`: settlement-worker delivery gate. Defaults to `false`; verified results can remain durably pending while it is off.
- `VS_ENABLE_PUBLIC_LEADERBOARDS`: public Global Rank proxy gate. Defaults to `false` and is independent of matchmaking and rank mutation.
- `VS_ENABLE_PUBLIC_CONTESTS`: durable non-economic contest API gate. Defaults to `false`; it additionally requires the durable core and PostgreSQL store.
- `VS_ENABLE_PUBLIC_TIME_PUZZLES`: exposes posted weekly/monthly/seasonal 3-map and 5-map Time Puzzles. Defaults to `false`.
- `VS_ENABLE_PUBLIC_GAUNTLET`: exposes the posted weekly frozen 18-stage Gauntlet. Defaults to `false`.
- `VS_PUBLIC_CONTEST_GRANT_SECRET`: at least 32 characters; HMAC-binds server-issued attempt grants. It is never returned. Keep it in managed secret storage.
- `VS_PUBLIC_CONTEST_LEADERBOARD_LIMIT`: maximum returned public contest rows, clamped to `1..100`; defaults to `25`.
- `VS_DURABLE_STORE`: `memory` or `postgres`. Defaults to `memory`; staging/production durable-route migration will require `postgres`.
- `VS_DATABASE_URL` (or `DATABASE_URL`): PostgreSQL connection used by the durable core.
- `VS_DATABASE_POOL_MAX`: PostgreSQL pool size. Defaults to `16`.
- `VS_DURABLE_RETENTION_DAYS`: evidence retention floor. Defaults to `120`; no cleanup job currently deletes durable evidence.
- `VS_PUBLIC_1V1_MINIMUM_CLIENT_BUILD`, `VS_PUBLIC_1V1_SIM_BUILD_ID`: pinned client/simulation compatibility policy.
- `VS_PUBLIC_1V1_RULESET_ID`, `VS_PUBLIC_1V1_RULESET_HASH`, `VS_PUBLIC_1V1_MAP_ID`, `VS_PUBLIC_1V1_MAP_HASH`: server-owned immutable Standard 1v1 content snapshot. Hashes are lowercase SHA-256.
- `VS_PUBLIC_CTF_*` and `VS_PUBLIC_HCTF_*`: server-owned immutable ruleset/map IDs and lowercase SHA-256 hashes for those modes. `VS_CTF_BOT_FALLBACK_THRESHOLD_SEC` defaults to 30 seconds; bot profile IDs are server-owned and canonical.
- `VS_PUBLIC_1V1_RECONNECT_GRACE_SEC`: stored reconnect grace duration. Defaults to `30` seconds.
- `VS_PUBLIC_1V1_AUTHORITY_TIER`: frozen contract authority tier. Defaults to `RELAY_ATTESTED`; trusted verification jobs require `AUTHORITY_VERIFIED`.
- `VS_MATCH_VERIFICATION_ENABLED`: isolated result-verification route gate. Defaults to `false` and also requires both durable gates.
- `VS_VERIFIER_WORKER_TOKEN`: dedicated verifier-worker credential for job lease/complete/fail. It is separate from player, admin, and legacy match-authority credentials.
- `VS_VERIFIER_KEY_ID`, `VS_VERIFIER_PUBLIC_KEY_PEM`: exact ES256 verifier receipt key accepted by VS. VS does not hold the private key.
- `VS_VERIFIER_WORKER_BUILD_ID`: pinned worker build bound into every accepted receipt.
- `VS_VERIFIER_LEASE_SEC`, `VS_VERIFIER_RETRY_DELAY_SEC`: at-least-once worker lease and retry timing.
- `VS_RANK_SERVICE_URL` and `VS_RANK_SERVICE_TOKEN_*`: Rank service location and short-lived ES256 service identity. VS holds the private key; Rank receives only the public key.
- `VS_RANK_SETTLEMENT_LEASE_SEC`, `VS_RANK_SETTLEMENT_RETRY_DELAY_SEC`, `VS_RANK_SETTLEMENT_POLL_MS`: durable at-least-once settlement-worker timing.
- `VS_RANK_LEADERBOARD_MAX_STALE_SEC`: maximum age for the last server-fetched Global Rank snapshot. With no snapshot, or after this bound, reads fail closed.
- `VS_AUTHENTICATED_1V1_SLICE_ENABLED`: enables only the Package 1 authenticated Standard 1v1 queue proof. Defaults to `false`; it is not the public 1v1 release flag.
- `VS_PLAYER_TOKEN_ISSUER`, `VS_PLAYER_TOKEN_AUDIENCE`, `VS_PLAYER_TOKEN_KEY_ID`, `VS_PLAYER_TOKEN_PUBLIC_KEY_PEM`: exact ENTaP player-token verification contract. VS receives only the public key.
- `CRUCIBLE_LEDGER_STORE`: `file` or `memory` today; production target is `postgres`.
- `CRUCIBLE_LEDGER_PATH`: JSON snapshot path for the local/dev file-backed Crucible ledger. Defaults to `data/crucible-ledger.json`.
- `HONEY_LEDGER_STORE`: `file` or `memory` today; production target is the ENTaP player ledger.
- `HONEY_LEDGER_PATH`: JSON snapshot path for the local/dev file-backed Honey ledger. Defaults to `data/honey-ledger.json`.

Honey ledger notes:

- Honey is stored as integer `centi_honey`.
- `record_honey_activity` is the preferred award path; it calculates the reward server-side from activity key, expected duration, completion flags, and anti-farm signals.
- Mutating Honey writes require match-authority auth in this local service.
- Hive Honey purchases use member-owned proportional debits; there is no separate Hive treasury.
- The current file-backed ledger is a local/dev adapter. Production should replace it with the canonical ENTaP player Honey ledger and real identity validation.

Security Sprint 0 notes:

- Keep `VS_ECONOMY_MUTATIONS_ENABLED=false` and `VS_ECONOMY_RESET_ENABLED=false` until the separate server-side match authority is approved and deployed.
- Empty configured admin or match-authority tokens never authorize a request. Protected routes fail closed; free matchmaking does not require either credential.
- Money/Honey/Crucible histories, balances, payout reports, and ledger snapshots are admin-only. Public policy reads are `get_honey_policy`, `get_crucible_config`, and `get_wax_policy`.
- `debug_fill_quick_match` and `debug_fill_session` require VS admin authorization. TestFlight free bot play uses `fill_free_bot_match`, which rejects paid and Crucible contexts.
- Contest-dashboard create/update/delete operations require admin authorization and are quarantined with other economy mutations.

Package 1 player-auth notes:

- `enqueue_public_1v1` requires an ES256 player token with `match:queue` scope and derives the queue identity exclusively from token `sub`.
- A body `uid`/`player_id` that conflicts with `sub` returns `identity_mismatch`.
- Display identity comes from signed token snapshots; rank, Wax, color, and balance hints are discarded in this slice.
- The Package 1 proof match is forcibly `ranked=false`, `authority_tier=RELAY_ATTESTED`, and Standard/non-economic. The later durable route remains non-economic, takes its server-owned authority tier from disabled-by-default configuration, and freezes rank policy on only when the separate public-release gate is enabled.
- Player tokens do not satisfy admin or match-authority gates.
- `VS_AUTHENTICATED_1V1_SLICE_ENABLED=false` and `public_1v1_enabled=false` remain the default/reported posture.

Package 2 durable-core notes:

- Migration `001_vs_durable_core.sql` stores frozen contracts, roster v2, reconnect deadlines, lifecycle events, command streams/events, terminal receipts, idempotency receipts, and player outbox events.
- `PostgresDurableCoreRepository` acknowledges a command only after its transaction commits and allocates command sequence numbers while holding the stream row lock.
- Contract, command, result, and outbox retries return the original durable receipt; reusing an idempotency key with different canonical content is rejected.
- `MemoryDurableCoreRepository` is a semantic test adapter. It is not an authorized public-production store.
- To validate schema/restart behavior without a local PostgreSQL daemon, run `npm run smoke:durable-core`. It applies the real migration to embedded PostgreSQL with `pgcrypto` and creates a fresh repository instance over the same database.

Package 3 durable Standard 1v1 notes:

- Migration `002_authenticated_1v1.sql` adds durable queue tickets and atomically pairs compatible authenticated players into the Package 2 contract/roster/command tables.
- The JWT subject owns every queue, lifecycle, command, reconnect, and read action. Seats, teams, colors, command sender, sequence, and execution tick are server-owned.
- The canonical response is `roster[]`; `host` and `guest` are derived two-seat projections only.
- Queue/lifecycle/command retries are idempotent, and `poll_public_1v1` plus `resume_public_1v1` recover state through a fresh PostgreSQL repository instance.
- The Godot seam opts in with `durable_public_1v1=true`, sends protocol v2 plus `SF_PUBLIC_CLIENT_BUILD` (or `swarmfront/vs/public_client_build`), and routes later generic session/intent calls by remembered durable match ID.
- Run `npm run smoke:durable-1v1` for embedded PostgreSQL restart evidence plus the authenticated HTTP lifecycle. Public rank and economic effects remain disabled.

Trusted result-authority notes:

- Migration `003_match_verification.sql` stores player diagnostic terminal reports, durable verification jobs/leases/runs, and detached ES256 receipts.
- Two authenticated roster reports schedule one stable replay subject. Their winner, time, and hash claims are diagnostics; only the worker's replay or a trusted lifecycle record can create the terminal receipt.
- The separately deployed `../match-authority` worker verifies the pinned map/rules bytes, runs the same headless Godot replay twice, signs the immutable result, and converts trusted replay disagreement to `NO_CONTEST`.
- Result reads are roster-owned and return the existing terminal result plus signed receipt after reconnect/restart. Worker writes use only `VS_VERIFIER_WORKER_TOKEN`; players cannot lease or complete jobs.
- Run `npm run smoke:verification` for PostgreSQL restart/idempotency/signature evidence. Keep `VS_MATCH_VERIFICATION_ENABLED=false`, rank mutations disabled, and economy mutations disabled until staging gates pass.

Standard 1v1 release-candidate notes:

- Migration `004_standard_1v1_rank_settlement.sql` stores one settlement job per verified result, expiring leases, retry evidence, and the committed Rank response.
- Reconciliation selects only signed, `AUTHORITY_VERIFIED`, `STANDARD_1V1` results whose frozen contract enabled `STANDARD_1V1_V1` rank policy. `NO_CONTEST` becomes `NOT_APPLICABLE`.
- The settlement worker sends the signed verifier receipt server-to-server. It never accepts a winner, placement, rank delta, or identity from a player client.
- Expired reconnect grace is decided from durable server time and creates one `MATCH_FORFEITED` lifecycle event plus a `SERVER_LIFECYCLE` verification job; it does not let a client declare the forfeit.
- The Rank panel's Global tab uses only the shared server board. A cached server snapshot is labeled with age; absence of a bounded snapshot displays unavailable instead of substituting local rank fixtures.
- Run `npm run smoke:standard-1v1-release` for disconnect expiry and settlement retry/restart/idempotency evidence, and `npm run smoke:public-rank` for live/cache/fail-closed board behavior.
- The three release flags remain false by default. No deployment or production flag change is part of this package.

Durable public-contest platform notes:

- Migration `006_public_contest_platform.sql` stores server-authored definitions, real authenticated rosters, attempt grants, verifier-authoritative results, one best row per player, final placements, and stable outbox messages.
- Public contest routes refuse the memory adapter. Definitions and boards come only from PostgreSQL and carry `source=SERVER_PUBLIC_CONTEST_STORE`; bundled `.tres`, `ContestState.runtime_leaderboards`, and `user://` files have no ingestion path.
- `enter_public_contest` derives the player from an ES256 token with `contest:play`. Result commits require the separate match-authority credential; client score claims cannot write a public row.
- Reconciliation uses server UTC for open, attempt deadline, close, placement snapshot, and fixed-interval rollover decisions. Historical boards retain their contest and leaderboard IDs.
- Closing a contest snapshots deterministic placement and writes top-three messages to the existing durable outbox in the same transaction. Delivery acknowledgement is idempotent.
- This platform is non-economic and does not import or invoke `MoneyLedger`. `publish_public_time_gauntlet_periods` freezes six Time Puzzle definitions plus the weekly 18-stage Gauntlet from the Godot-exported catalog.
- Migration `007_time_gauntlet_evidence.sql` stores player evidence in a leased worker queue. Evidence cannot alter a board; only a verifier-worker completion can call the trusted result projection.
- Run `npm run smoke:public-contests` and `godot --headless --path . --script res://tools/public_time_gauntlet_smoke_test.gd` for cross-runtime comparator fixtures, period separation, exact content hashes, Dash navigation, evidence authority, persistence, and best-per-player boards.

Managed PostgreSQL setup:

```bash
VS_DATABASE_URL=postgres://... npm run migrate
VS_DATABASE_URL=postgres://... VS_DURABLE_STORE=postgres npm run start
```

Keep `VS_DURABLE_CORE_ENABLED=false` and `VS_DURABLE_PUBLIC_1V1_ENABLED=false` until managed-PostgreSQL restart/load tests and two-device staging certification are complete.

Wax ledger notes:

- Canonical Wax is owned by the rank/ENTaP identity layer, not the VS Crucible ledger.
- `record_competitive_wax_result` is deprecated and suppressed for compatibility; it must not mint or subtract Wax.
- Approved async contest payout reports do not publish Wax into the Crucible ledger.
- Crucible only escrows, refunds, and pays out optional 1-Wax wagers. There is no burn.
- RankState `wax_score` is the current canonical local implementation of player Wax.

Production Crucible requirements:

- Supabase Postgres-backed `CrucibleLedgerStore`.
- Supabase Auth validation for users/admins.
- Backend-issued short-lived signed JWTs for admin and match-authority operations.
- No client-provided authority should be trusted for settlement, escrow, or privileged admin writes.

For Crucible launch operations, see `../../docs/economy/crucible_launch_runbook.md`.

## Deploy

Use any Node HTTPS host such as Render, Railway, or Fly. Most hosts terminate TLS for you and provide a public HTTPS URL.

Build command:

```bash
npm install
npm run build
```

Start command:

```bash
npm start
```

Set `PORT` only if your host does not inject it automatically.

After deployment, use this base URL in Godot:

```ini
swarmfront/vs/backend_url="https://YOUR_HOSTNAME/v1"
```

Verify before exporting TestFlight:

```bash
godot --headless --path ../.. --script res://scripts/dev/vs_pvp_smoke.gd --vs-smoke-backend-url=https://YOUR_HOSTNAME/v1
```

Local money-game transport smoke:

```bash
PORT=8791 BIND_HOST=127.0.0.1 npm start
SF_VS_BACKEND_URL=http://127.0.0.1:8791/v1 godot --headless --path ../.. --script res://tools/money_game_backend_transport_smoke_test.gd
```
