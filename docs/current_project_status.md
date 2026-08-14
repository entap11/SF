# Current Project Status

Date: August 14, 2026

## August 14 third-strike client presentation correction

The server-side reconnect sequence now passes the physical three-disconnect
check: Android did not receive victory until the third deliberate iPhone app
exit. The reciprocal path is still **FAILED / NOT CERTIFIED**, however, because
the disconnected iPhone continued showing a fresh 60-second countdown after
the server had already reached the authoritative 3/3 forfeit result.

Commit `844d9dbdd31d061afc8af0dde75852aef745ea8b` corrects that client-only
presentation defect. When the latest authoritative snapshot already records
2/3 local disconnect strikes, another local interruption now locks controls and
shows `FINAL DISCONNECT PENDING` without inventing a new 60-second grace timer.
The client still does not decide the outcome. When a reachable server response
reports `forfeit` or `no_contest`, that terminal authoritative presentation now
takes priority over the local transport-interruption overlay.

Automated verification passed under exact Godot
`4.7.1.stable.official.a13da4feb`: reconnect lifecycle (including executable
2/3-pending and terminal-priority assertions), app lifecycle, Arena pause
source, private PvP certification UI, VS swarm replication, human PvP boot, and
outcome overlay. The VS TypeScript build and full service smoke also pass, as
does `git diff --check`.

Updated debug-signed clients from exact commit `844d9db` are installed on both
physical phones with existing application data preserved:

- Android APK SHA-256:
  `a1c365f37abfc7c4f00132ed211c028e6c0fc50865f4f0e4f6d320d5db094360`
- iPhone executable SHA-256:
  `7db8333f9b2564bdca9aad0dd0ca676990613a28f779f8915718ce79792f0a15`
- iPhone PCK SHA-256:
  `d3871b719ffd3bb7863dd27c8ad7df339f646bcbca1e96686255502ed7ca77e0`

No additional Render change was required. Production VS remains live at exact
server commit `be694ddfda64694023a3320b92755d54c73ed59b` in deploy
`dep-d9vjg16gekts73fr8umg`, with all public/economic mutation capabilities
disabled. Physical acceptance now requires one fresh three-disconnect match:
confirm 1/3, then 2/3, then Android victory on 3/3 while the offline iPhone
shows the pending state without a timer; after restoring connectivity, confirm
the iPhone replaces that pending state with the authoritative terminal result.

## August 14 reciprocal reconnect correction

The reciprocal iPhone test remains **FAILED / NOT CERTIFIED**. Two deliberate
iPhone app exits while operating airplane mode caused the Android player to
receive a disconnect victory instead of leaving the iPhone at 2/3 strikes.
Because iOS retained Wi-Fi, that operation did not independently prove the
local transport-loss presentation, but two app-background/resume cycles
producing a third-strike forfeit is valid lifecycle-accounting failure evidence.

The remaining server defect was reproduced locally. The `match_presence`
endpoint evaluated stale players before refreshing the caller represented by a
current `foregrounded` request. The service smoke failed before correction with
that caller moved to `grace`, `presence_timeout`, and strike 1. Commit
`be694ddfda64694023a3320b92755d54c73ed59b` now records current foreground,
active, and background presence before stale-player evaluation. Grace expiry,
checkpoint selection, strike ownership, and terminal results remain
server-authoritative.

Verification after the correction:

- VS TypeScript build: PASS;
- full VS service smoke: PASS, including the failing-before foreground-order
  regression and an assertion that resume after disconnect two remains 2/3;
- Godot `4.7.1.stable.official.a13da4feb` reconnect lifecycle: PASS;
- app lifecycle and Arena lifecycle pause smokes: PASS;
- VS swarm replication: PASS;
- private PvP certification UI: PASS;
- human PvP boot: PASS; and
- `git diff --check`: PASS.

The isolated service correction is live on production service
`srv-d7uho16gvqtc73feh9s0` as Render deploy
`dep-d9vjg16gekts73fr8umg`. Live `/v1/health` reports exact build `be694dd` and
keeps every public/economic mutation capability disabled. No database, secret,
configuration, plan, or capability changed. Previous deploy
`dep-d9v5jq7lk1mc73902mug` at `4a3f4b6` is the rollback anchor.

Physical acceptance is still required from a fresh session: confirm the first
and second iPhone background/resume cycles report exactly 1/3 and 2/3 without a
forfeit, then confirm a deliberate third cycle forfeits. Separately, repeat the
true transport-loss case with iPhone Wi-Fi disabled and cellular as the active
path before airplane mode, so the app can remain foregrounded while the network
actually disappears. No phone rebuild is required for this server-only fix.

## August 13 physical reconnect addendum

Overall release status remains **HOLD**, but the Android airplane-mode reconnect
path passed a two-phone physical test against the existing live VS service. No
Render service, database, configuration, secret, deployment, or capability was
changed during this test.

What changed in the uncommitted candidate:

- A client-side transport interruption now immediately blocks gameplay input
  and presents `CONNECTION INTERRUPTED` on the disconnected phone.
- The local display estimates the server's presence-stale boundary from the
  last authoritative server clock, holds at the configured 60-second grace
  value until that boundary, and then follows the estimated authoritative
  deadline until reachable lifecycle data replaces it.
- Simulation pauses at the predicted server grace boundary instead of running
  indefinitely while offline. The server remains authoritative for grace,
  strikes, checkpoint selection, restore, and resume.
- The server source now publishes `presence_stale_ms`; this source change was
  not deployed. The tested clients use the matching 2,500 ms compatibility
  fallback with the currently deployed server.
- The six-tick PvP command lead and 2x invite-code font remain included.

Automated verification passed:

- reconnect lifecycle smoke;
- VS swarm replication smoke;
- private PvP certification UI smoke;
- VS service TypeScript build and service smoke;
- `git diff --check`.

Physical evidence, session `S46120393`:

- Android airplane mode produced the immediate local warning; iPhone produced
  the server-authoritative peer-disconnect warning.
- Android's last connected server report was tick 480. Only five subsequent
  failed state-hash publishes occurred, at ticks 485 through 505, after which
  local simulation stopped. This replaces the prior failure mode where the
  offline client advanced by hundreds of ticks.
- iPhone reached tick 514 before the server entered grace, and the server chose
  tick 514 as the authoritative recovery checkpoint.
- Android reconnected before expiry. Both clients returned to `running` at
  ticks 549/548 and remained aligned at ticks 1079/1076.
- The product owner visually confirmed that reconnection restored the same
  state on both phones. No state-hash mismatch was recorded for this session.
- Android correctly recorded disconnect strike 1/3.

Later reciprocal iPhone testing exposed two additional defects; that test is
therefore **not certified**:

- While iPhone remained in airplane mode, a pre-interruption HTTP completion
  could be mistaken for restored connectivity. The local popup disappeared and
  simulation continued after a touch coincided with that stale response.
- Two deliberate iPhone outages were recorded as three strikes. Live session
  `S61434264` terminated with `disconnect_strike_limit`, epoch 18, and iPhone at
  3/3 even though the product owner performed only two outages.

The next uncommitted candidate rejects responses whose request began before
local outage detection, prevents authoritative `running` updates from hiding
an active local interruption, and consumes all input while the disconnect
overlay is visible. The server now refreshes the caller before stale-presence
evaluation and starts a fresh presence window when synchronized resume becomes
`running`, preventing the resume-boundary poll from becoming a phantom strike.
Focused lifecycle, replication, UI, TypeScript build, service smoke, and diff
checks pass with explicit stale-response and phantom-strike regressions. The
client correction is installed on both phones. The product owner explicitly
approved deploying the isolated server correction. Render deploy
`dep-d9v5jq7lk1mc73902mug` completed successfully and is live on service
`srv-d7uho16gvqtc73feh9s0` at exact commit
`4a3f4b6f44589fbcac8de43826cdac5beb25d340`. Live `/v1/health` reports that
build and keeps every economy/public mutation capability disabled. No database,
secret, configuration, or capability was changed. The previous production
deploy at `36614cc5ac93587e12dd870935d1fef6e584ae71` remains the rollback target.

Installed candidate artifacts:

- Android APK SHA-256:
  `d5c1e3f69211d4f3c8ddc7a70f5083c32b403d3d80421367be5dd89064b61227`
- iPhone executable SHA-256:
  `3846b740826fca8ce1e6f7f76f4db6c0ea269ad538dcc5dc5e281bf2a3763f5f`
- iPhone PCK SHA-256:
  `3fc63e65ed079b039e35b7ce91b847563afc4330f93a1a8bccd3423c572f1b49`

Remaining reconnect coverage:

1. Repeat the airplane-mode test with iPhone as the disconnected client and
   confirm touches cannot dismiss the local warning while still offline.
2. In that fresh session, confirm the first deliberate outage reports 1/3 and a
   second deliberate outage reports 2/3 without forfeiting.
3. Rerun the 3/3 disconnect-forfeit path on a deliberate test session.
4. Preserve the existing protected-key and unchanged-threshold performance
   gates from the August 12 sequence.

# Required report — HOLD

No Render service, database, configuration, secret, deployment, or capability was changed. Nothing was merged to `main`, and no Candidate Release Manifest was issued.

## 1. Executive status

**HOLD**

Two mandatory gates remain incomplete:

- Physical reconnect presentation requires hands-on operation of both phones.
- The unchanged performance threshold cannot be certified while this host is heavily CPU-contended.

## 2. Architecture freeze

Frozen in [ADR 005](architecture/render_reactivation/adr-005-render-reactivation-contract.md):

- `OpsState`/`SimState` remains authoritative.
- Client and authority worker must share one certified revision.
- Certification and Production remain separate.
- All public/economic/mutation capabilities remain default-off.
- PostgreSQL or the canonical durable store is required.
- HCTF and economic async contests remain excluded.
- Honey/Wax ownership remains unresolved.
- Candidate identity and live deployment facts are separated:
  - [Candidate Release Manifest](architecture/render_reactivation/candidate-release-manifest-v1.md)
  - [Deployment Manifest](architecture/render_reactivation/deployment-manifest-v1.md)
- Every changed Render component will require proven rollback.

## 3. Reuse findings

The [reuse report](architecture/render_reactivation/reuse_report_2026-08-12.md) found that SF already has:

- release-readiness and all-off preflight gates;
- VS/Rank migrations and database recovery checks;
- deterministic replay and authority-worker tooling;
- health, rollback, evidence, and remote-operations machinery;
- Android and iOS secure-credential implementations;
- Render blueprint and prior certification evidence.

No replacement deployment framework or parallel certification harness is justified.

## 4. Render estate

The complete read-only inventory is [here](architecture/render_reactivation/render_estate_inventory_2026-08-12.md).

| Estate | Current topology | Treatment |
| --- | --- | --- |
| Certification | VS, Rank, authority worker, source DB, restore DB | Reuse; upgrade services to the exact 4.7.1 candidate |
| Production | One private `SF` VS service | Reuse as private VS/rollback anchor; reconfigure and upgrade |
| Legacy Rank | Rank service plus PostgreSQL outside Production environment | Reuse/migrate decision remains open |

Production still lacks an attached Rank/identity service, managed database, and authority worker. Existing Honey/Crucible file stores and money memory stores are not acceptable production authority.

## 5. Current → target delta

- Certification authority remains pinned to Godot 4.2.2 and needs the future candidate.
- Production needs durable authenticated VS configuration, Rank/identity, PostgreSQL, and a separate authority worker.
- Production environment protection/network isolation requires a later decision.
- Honey/Wax canonical ownership remains unresolved.
- No evidence supports creating a parallel “Production v2.”
- Every eventual deployment must link back to the immutable candidate through a Deployment Manifest.

## 6. Godot 4.7.1 integration status

- Branch HEAD: `51b9f2f5de855cb22fbf4dc9dd969d14e41707f2`
- `origin/main`: `1fb58f844fc3fd21159aa9c347e94aef8fb4288c`
- Divergence: 34 branch-only commits, zero main-only commits.
- `origin/main` is the merge base, so there are presently no mainline merge conflicts.
- No merge or push was performed.

New isolated commits:

- `e81fd08` — corrected soak-gate map-readiness race.
- `0456ede` — built and linked the iOS credential plugin against Godot 4.7.1.
- `d317596` — exact Godot patch-version handling in TestFlight preflight.
- `8d0532a` — configured-backend testing made explicit opt-in.
- `51b9f2f` — self-contained local import and explicit local PvP smoke.

The iOS build/link evidence is recorded in [ios_secure_credentials_4_7_1_2026-08-12.md](architecture/render_reactivation/ios_secure_credentials_4_7_1_2026-08-12.md). Device-arm64 and universal simulator slices link successfully; physical Secure Enclave acceptance remains open.

Reconnect status:

- Automated lifecycle smoke: PASS.
- Certification UI smoke: PASS.
- Dirty reconnect diff remains unchanged, SHA-256 `85e877cfd393417e4fe38d311980f13c3daee28530a59321298f35378848a06e`.
- Physical 1/3, 2/3, third-forfeit, expiry, and both-host-direction presentation matrix: not completed.
- Reconnect work was not committed before the report stop.

Unrelated user-owned main-menu changes remain untouched and uncommitted.

## 7. Gate results and blockers

Local TestFlight preflight passed cleanly at `51b9f2f`, using exact Godot 4.7.1 and making no configured-backend request.

Performance diagnosis:

- The original soak could accidentally measure the startup map and re-enabled bots.
- That race is fixed without changing the 45 ms/8 ms thresholds.
- A valid 120-second run exited cleanly.
- Simulation passed: 7.9 ms maximum versus 8 ms.
- Renderer failed: 62.1 ms maximum versus 45 ms.
- The host was simultaneously running a VM at over 300% CPU, `bun audit` near 100%, Supabase reset work, and another long-running Godot smoke. Those processes were not stopped or altered.
- The full 30-minute certification run would not be credible under this contention.

Physical blockers:

- Android and iPhone are currently discoverable.
- Both-phone reconnect operation still requires hands-on interaction.
- Signed iPhone Secure Enclave/Keychain acceptance remains required.
- Fresh Android protected-key/device acceptance remains required.

## 8. Exact remaining sequence

When both devices are connected/unlocked and the host is idle:

1. Run the complete physical reconnect presentation matrix.
2. Run iOS and Android protected-key acceptance.
3. Commit only the certified reconnect diff.
4. Create a clean worktree at the exact resulting SHA.
5. Rerun all local, server, migration, native, matrix, and unchanged-threshold 30-minute soak gates.
6. Fast-forward `main` only if every gate passes.
7. Build clean Android/iOS/authority artifacts from that exact `main` SHA.
8. Populate and hash the Candidate Release Manifest.
9. Stop again before any Render deployment or Deployment Manifest creation.

## End-of-day preservation note

After the HOLD report above, the product owner explicitly ended physical
testing for the day and authorized committing and pushing the remaining work so
the branch and worktree could be left clean. That preservation commit does not
convert any outstanding physical or performance row into a pass. The reconnect
presentation remains provisional until the exact remaining sequence above is
completed.

End-of-day automated checks kept the reconnect lifecycle and certification UI
green. The payout-proof smoke and the focused free-roll background layer-order
smoke also passed. The broader free-roll layout smoke remains unresolved at
`weekly free roll did not open tournament lobby`; its preserved log is
`/tmp/swarmfront_main_menu_free_roll_full_final_2026-08-12.log` with SHA-256
`63c1c72d4f649691fe5e261502cc72bcde126ab1acc4b55c593acc5e673fbfb2`.
No fix or certification claim was added for that row.

---

# Historical Project Status — March 12, 2026

## Executive Summary

The project is in a good transition state.

The dash/garage pillar is scaffolded enough to pause.
The next active pillar is bot depth for 1P async.

## What Changed Recently

### Dash / Garage

- The dash drawer now uses top tabs:
  - Garage
  - Buffs
  - Achievements
- The old right-side dash hex stack is suppressed in the main dash flow.
- The garage is now the primary dash hero.
- The garage hero supports grab-and-rotate on the preview.
- The garage loadout shelf now has PvP and Time Puzzles context tabs.
- Power Bars are live through the existing theme system.
- Other garage categories are scaffolded and profile-backed, but not fully live due to missing assets/content.

### Dash Content Direction

- Buffs now have a dedicated dash hero surface.
- Achievements now have a dedicated dash hero surface.
- Achievements is intentionally broader than badges and is the likely future home for:
  - async records
  - awards
  - ribbons
  - recognition layers

### Bot Depth

- Bot support now has first-class style plus tier profile merging.
- Styles currently supported:
  - balancer
  - turtle
  - raider
  - greedy
  - swarm_lord
- Tiers currently supported:
  - easy
  - medium
  - hard
- The baseline bot policy now reads more style-specific scoring weights, so the bots differ in actual decision-making rather than only speed/aggression timing.
- Bot logging now includes style and tier in intent telemetry logs.
- Async `VsLobby` now has debug CPU style and tier selectors for 1P testing.

### Async / Stage Race Stability

- `MAP_TEST` was removed from the normal playable map path.
- `Stage Race` contest map resolution was fixed to stop falling back from stale `tp_map_*` ids into unintended boards.
- Camera fit was corrected so full-board map bounds are used unless node-bounds fit is explicitly enabled.
- The `PowerBar` alpha/visibility path was corrected so it can actually appear once the match goes live.
- Match flow start is now deferred by a couple of frames so async prematch is less likely to burn during shell boot.
- Async prematch now has a dedicated mode card path instead of relying entirely on the default 1v1 countdown presentation.
- The async prematch card now covers:
  - `Stage Race`
  - `Timed Race`
  - `Miss N Out`
  - direct Jukebox single-map runs
- Async prematch keeps the `PowerBar` visible during those modes so the run starts with better gameplay context.
- Jukebox easy-bot prematch labeling no longer falls back to misleading generic bot text.

## Current Product Read

### Solid

- Dash shell direction is coherent.
- Garage belongs inside dash.
- Top-tab structure is the right long-term move.
- 1P bot work is the correct next focus and is the backbone for async.

### Not Done

- Garage categories beyond Power Bars still need assets/content before they can be fully validated.
- Buffs dash surface is still a summary/scaffold rather than the final full editor.
- Achievements/records schema is not fully defined yet.
- Bot personality separation still needs tuning; early playtest read is that `balancer` and `raider` currently feel too similar.
- Async prematch presentation exists now, but the next pass should be UI/UX polish rather than more plumbing:
  - layout
  - spacing
  - copy hierarchy
  - overall readability / feel
- Player-facing bot customization UI/UX is still intentionally unresolved beyond the current debug selectors.

## Important Future Note

At some point, swarm_lord should become swarmfather.

That bot is intended to become the first modeled-player bot based on real telemetry, not just a hand-authored style.
That future work should include:

- telemetry collection requirements
- clean storage and compilation
- analytics views
- ghost / modeled-player behavior fitting

## Recommended Next Steps

1. Spend the next work block on async prematch UI/UX polish, not new system plumbing.
2. Tune bot separation, starting with `balancer` vs `raider`.
3. Start capturing structured playtest perception notes so bot feel can be tuned against human-readable reports, not just telemetry.
4. Return to garage only after art/content for the remaining categories exists.

## Verification Note

Validated on March 12, 2026:

- `godot --headless --path . -s tools/map_record_stage_race_runtime_smoke_test.gd` passes.
- `scripts/dev/run_mvp_smoke.sh` passes with `18` passes and `0` fails.
- `godot --headless --path . --quit` still returns the known non-zero headless exit tied to the existing rank transport fallback.

Known existing non-zero exit:

RANK_TRANSPORT_FALLBACK
