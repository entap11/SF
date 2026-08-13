# Current Project Status

Date: August 12, 2026

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
