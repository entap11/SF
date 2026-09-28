# Beta game capture

Requested September 28, 2026: collect beta games, including the owner's, for bot
behavior and audience difficulty review. Gameplay authority remains
`OpsState`/`GameState`; the archive is a read-only gameplay projection. This work
changes no bot policy, difficulty, rewards, verified results, or matchmaking.
Owner victories must not become the target difficulty for ordinary players.

## Recording and sharing

All three beta export presets carry `beta_capture`. Every Arena session attaches
the existing telemetry collector automatically. A tester chooses **Share beta
games** once; **Keep on this device** continues local recording. The choice can
be changed in Support or the bot playtest hub. Uploads use the existing player
session, occur outside active games, and stop when a game begins. No operator
credential ships in the game.

Each recording contains:

- Build/source, engine/platform, map/hash, mode, seed, local seat, and effective
  bot profiles, so results from different candidates remain distinguishable.
- Player/bot actions and intents, sampled hive/lane state, and per-seat metrics.
- Completed, abandoned, or interrupted status, elapsed simulation time, and winner
  when available. Active games checkpoint at start and every 15 seconds; a crash
  may lose the time since the last successful checkpoint.

Names, account UUIDs, opponent identities, chat, payment data, tokens, arbitrary
profile dictionaries, and bot observation/memory dictionaries are excluded.
Participant keys hash the canonical player ID: they are pseudonymous, not
anonymous. Board samples are useful for strategy review; they are not a complete
video or deterministic replay. The current event projection includes action,
bot-decision, and buff events (collector event kinds 4, 5, and 9).

Files are atomic gzip checkpoints under
`user://beta_captures/<participant_key>/<capture_id>.json.gz`. The queue retains
files until a receipt matches the capture ID and the exact bytes still on disk.
Retries are safe after lost replies; a reused ID with different contents gets
409 rather than replacing evidence. Only records belonging to the currently
authenticated identity upload. Offline records stay on the device until that
identity authenticates and sharing is enabled.

Limits are explicit: 20,000 events (first and last halves retained, dropped count
recorded), at most 3,601 board samples (stride recorded), 8 MiB decoded / 2 MiB
compressed per record. At 1,000 queued files or 256 MiB the client stops starting
new recordings and reports storage pressure instead of deleting unacknowledged
games. One active recording can exceed the queue threshold by up to one payload.
The server admits at most 500 new records / 128 MiB per player per rolling day.
Failures remain queued with diagnostics. This is bounded collection, not a
promise of lossless recording under storage exhaustion or device loss.

## Authority, privacy, and archive operations

`sf_beta_participants` and `sf_beta_captures` in the existing Rank identity
PostgreSQL database own archive acceptance. Uploads validate the player JWT,
active session/account, schema whitelist, size and digest. A second session check
inside the existing account/Rank advisory lock prevents insertion racing account
deletion. Stored payloads are immutable and never award rank or currency.

`POST /v1/beta-captures` requires `SF_BETA_CAPTURE_ENABLED=true` and player auth.
Private listing/download/cohort routes require the existing operator bearer
authentication. Unknown cohorts stay unknown; skill is never guessed from a win.
Account deletion stops local recording, clears queued captures and sharing
preferences, and deletes the server participant with cascading archive deletion.
There is no automatic age-based archive expiry in this first version. Private
operator exports must also be removed when fulfilling an account deletion; they
are not remotely erased by the database cascade.

Download a private archive using an operator credential supplied securely through
`SF_BETA_ARCHIVE_TOKEN` (never put its value in commands or source):

```sh
python3 tools/collect_beta_games.py \
  --url https://swarmfront-cert-rank.onrender.com/v1 \
  --output ../artifacts/beta-games
```

The tool verifies hashes and recording identities and writes `recordings/`,
`index.json`, and `participants.json`. It groups by participant and cohort,
preserving owner/new/intermediate/experienced/unknown separation. Counts are
participant recordings; two phones in a multiplayer game can produce two
records. The hashed shared-match key permits later pairing when available.

After identifying the owner's participant key from a real capture, repeat the
command with `--label-participant <64-character-key> --cohort owner`. Do not infer
skill or pool owner results into a single target win rate. Cohort labels annotate
the participant; they do not rewrite original gameplay payloads. The two prior
owner bot games remain in their existing local evaluation archive; test-format
conversions were fixtures and were not uploaded as new games.

## Build and deployment

Build `2026092802` uses Godot `4.7.1.stable.official.a13da4feb`. Before exporting,
run `python3 tools/build_beta_capture_manifest.py`; commit the generated manifest
with the source. `--check` is part of the release readiness gate. The export
presets explicitly include the JSON manifest. Source hash for this development
package: `e8489b67a9e7606ec68eaee6626771d259b123362a7861a0aa1fb7391ef289eb`.

The certification backend change is isolated in deployment commit
`112c3d2fc7c9c877237d6866ddd5eb1283d36744`, based on the previously live
`d0009218c9a5d9081854d4e02fd186736a76f771`, preserving its identity fixes. Target:
`swarmfront-cert-rank` / `srv-d9f6j1l7vvec73foama0`; database `swarmfront_cert`.
Only `SF_BETA_CAPTURE_ENABLED` was enabled; economy mutation flags remain unchanged.

Apply checked-in `012_beta_match_capture.sql` through the existing database owner
before deploying to this restricted runtime. Runtime role
`sf_cert_rank_runtime` intentionally lacks REFERENCES on `rank_players`; the
first attempted runtime migration failed and left the prior service live. The
migration owner applied the exact file transactionally, recorded it in
`schema_migrations`, and granted the runtime SELECT/INSERT/UPDATE/DELETE on the
two new tables plus USAGE/SELECT on their sequence. No wider role privileges
were added. All 13 existing player rows were checked unchanged. Migration SHA-256:
`849197db93c1d5594fb902604ab01550151d48bc0e820e417d9c892e19a19de9`.

Existing installed builds do not gain recording remotely. The owner development
build is the first device pilot. Other testers need an updated, release-validated
beta before their games can feed the archive; TestFlight/Android distribution
is not claimed by this implementation.

Deployment `dep-dat9bnd9fdbs7387l91g` became live September 28 at 16:31:54 UTC.
Live health reports the exact deployment commit. Unauthenticated upload and
listing return 401, and the authenticated private export succeeds (zero records
at activation). `live-verification.json` records these checks. The signed app
was installed as an update on Matthew’s iPhone 16 Pro and launched; device app
inventory confirms build `2026092802`. Existing app data was preserved. The
one-time sharing choice and first real uploaded game remain the device pilot.

## Validation evidence and limits

Artifacts are in `../artifacts/beta-capture-2026-09-28/`:

- `client-smoke.log`: real projection, privacy exclusions, read-only behavior,
  checkpoint recovery, bounded events, stale/negative/mismatched receipts, and
  valid receipt deletion passed. Both prior real owner games decode through the
  server schema (Raider: 98 events / 224 frames; Balancer: 255 / 210).
- `arena-smoke.log`: both bot Arena flows produced completed general captures
  with actions, samples, winner, and effective policy; test passed.
- `transport-smoke-4.log`: actual HTTP uploader retained a 503 response, retried
  identical bytes, and removed the file only after the exact 200 receipt. No
  upload while a match was active. Isolated synthetic identity, no live uploads.
- `backend-smoke.log`, `deletion-smoke.log`, and corresponding `deploy-*` logs:
  PostgreSQL-backed auth, payload/privacy rejection, compression bound, duplicate
  and conflict behavior, admin access/export/cohort pagination, revocation, and
  account deletion passed on both source and exact deployment branches.
- `export.log`, `xcode-build.log`, `app-verification.json`: iOS export/build,
  code-signature verification, bundle build, and embedded/exported PCK identity.
  Pack inspection confirms the manifest and recorder are present.
- `live-migration.json`: target, migration hash, existing player integrity, and
  restricted runtime grants.

The broader fast release gate did **not** pass: onboarding restart testing hit
its 90-second subprocess timeout; a focused retry also timed out in an online
restart phase. Existing headless shader diagnostics appear in these logs, but
the cause of the timeout has not been established. Do not call this a passing
release gate or a store release candidate. Dedicated capture tests pass; a real
phone game/upload after the sharing choice is still needed for field validation.
