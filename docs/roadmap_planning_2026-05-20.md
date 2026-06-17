# Swarmfront Roadmap Planning

Date: May 20, 2026

Source: `docs/roadmap_planning_2026-05-06.md`, plus the Social Highlights planning and first implementation pass.

## Current Read

Gameplay remains at or near MVP. The core match loop is no longer the main blocker. The remaining work is product hardening, beta readiness, and infrastructure.

The May 6 plan still has open work in:
- gameplay soak and performance validation
- map/mode eligibility rules
- menu cleanup
- beta packaging
- async format hardening
- progression/economy clarity
- content, sound, vibration, and polish

Newly added work:
- Social Highlights: real gameplay video capture, highlight routing, player/hive opt-ins, platform posting, storage, and acquisition links.

## MVP Definition

MVP means:

Play a valid map, understand the board state, make lanes, watch deterministic unit flow, finish the match, and trust the result.

MVP does not require:
- final menus
- final economy
- final progression
- all map families
- all async formats
- final art for every surface
- production Social Highlights posting

## Completed Or Mostly Completed Since May 6

Social Highlights foundation:
- Garage now has a Social category with per-platform toggles defaulting off.
- Profile persistence supports social destination preferences.
- Match telemetry now carries an actual-Arena video replay package.
- Highlight analytics payloads now include video asset metadata and acquisition link metadata.
- Social routing jobs now carry video/acquisition fields.
- A standalone Godot render worker can render actual Arena frames from a replay package.
- A Node encoder can convert captured PNG frames to MP4.
- Highlight tests and telemetry smoke tests cover the new video contract.

Important constraint:
- Headless Godot with the dummy renderer cannot capture the real viewport. Production rendering needs a graphics-capable worker environment.

## Priority 1: Gameplay Soak And Lag Pass

Goal: prove the current gameplay loop holds up under pressure.

Carryover status:
- Headless soak gate measures Arena script cost, lane/unit renderer cost, and sim tick cost separately.
- 30-second gate passes were green on current public 545, 323, and Delta targets.
- Execution-opportunity telemetry is throttled.

Remaining tasks:
- Run repeated matches on the public 545, 323, and Delta pools.
- Track visible unit count, frame hitches, lane-heavy scenarios, and pass-through behavior.
- Validate on target phone viewport, not only desktop/headless.
- Fix only the top visible lag sources that affect actual play.

Exit:
- no obvious frame hitches during normal MVP play
- no visible pause in max-hive pass-through
- no unreadable unit/lane/hive state on target phone viewport

## Priority 2: Map And Mode Eligibility

Goal: prevent invalid map/mode combinations before they reach play.

Rules:
- Free Roll should keep the available map catalog broad, but filter by game type/topology.
- 3P games can only use maps tagged or declared as `3p`.
- 1v1, 2v2, 4P FFA, CTF, and Hidden CTF can use the shared non-3P map set when the topology supports the selected game type.
- Hidden CTF can use only maps with an even hive count.
- Hidden CTF runtime state should contain no NPC hives and should split hives evenly between P1/P2 through seeded allotment.
- 656 maps remain sandboxed unless deliberately reintroduced.

Remaining tasks:
- Confirm every Free Roll mode uses metadata/topology instead of filename suffix assumptions.
- Confirm CTF and Hidden CTF filter from the shared non-3P set.
- Add smoke coverage proving 3P modes only draw 3P maps and non-3P modes exclude 3P maps.
- Add author-facing map metadata only where filename and structural checks are not enough.

Exit:
- Free Roll can randomize any available map that matches the selected game type.
- Invalid game/map combinations are blocked before match launch.

## Priority 3: Social Highlights Infrastructure

Goal: automatically or manually post exciting match videos to approved destinations, using real gameplay footage and acquisition links.

Current product direction:
- Garage Social tab controls player destination opt-ins.
- Each destination has its own toggle.
- Default is off for player destinations.
- Swarmfront retains the right to auto-post sufficiently exciting matches to official channels.
- Either player can manually post shortly after match end.
- Hive-owned feeds/channels can receive hive highlights when configured.
- Public copy should avoid exposing the proprietary excitement score. Use language like: "If a match is exciting enough for people to want to watch, it may be featured."

Already implemented foundation:
- Social preference storage.
- Highlight video payload contract.
- Acquisition/deep-link metadata.
- Actual Arena replay package in match telemetry.
- Renderer CLI for actual gameplay frames.
- MP4 encoder CLI.
- Highlight routing metadata for video and links.

Remaining infrastructure:
- Provision a graphics-capable render worker environment.
- Decide one-render-per-process as the default until Godot standalone cleanup warnings are fully solved.
- Add render job orchestration: match end -> excitement evaluation -> render -> encode -> upload -> post jobs.
- Add durable MP4 storage and CDN URLs.
- Add retention policy for video assets and replay packages.
- Add platform credential management.
- Add Discord and Slack posting first.
- Add internal Hive feed posting.
- Add Instagram/TikTok posting after real API/account setup.
- Finalize App Store / landing / deep-link target.
- Add post-click tracking by match, campaign, and destination.
- Add retry, failure state, and admin visibility for failed posts.
- Add sandbox E2E tests for Discord/Slack and internal feed.
- Add real account test plan for Instagram/TikTok later.

Known technical note:
- The render worker currently produces valid output, but Godot still logs script-resource cleanup warnings at process exit after loading the full Arena scene. Treat this as acceptable for isolated short-lived render jobs, but do not run many renders inside one long-lived Godot process until this is resolved.

Exit:
- a completed match can produce a CDN-hosted MP4 from actual gameplay
- official-channel auto-post works for qualifying highlights
- player opt-in posts route only to enabled destinations
- hive feed/channel route works when configured
- each post has a working app acquisition link
- failures are visible and retryable

## Priority 4: Menu Cleanup

Goal: make the product shell intentional enough for beta.

Carryover status:
- Parked during the May 6 pass while map/mode rules, soak, and beta infrastructure were checked.
- Current read is that menus are working well enough to avoid broad churn, but beta polish still needs a focused pass.

Remaining tasks:
- Clean Free Roll game hub flow.
- Remove dead/debug menu paths from player-facing screens.
- Normalize labels for Race, Stage Race, Miss-N-Out, CTF, and Hidden CTF.
- Ensure back/close behavior is consistent.
- Keep dashboard, garage, buffs, and achievements scaffolded but not overbuilt.
- Add Social tab copy that is clear without exposing proprietary scoring.

Exit:
- user can launch MVP modes without dev knowledge
- no duplicated or misleading mode buttons
- no stale debug wording in the main flow
- Social settings are understandable and default-safe

## Priority 5: Beta Packaging Gate

Goal: get a build that can go to TestFlight without gameplay churn.

Remaining tasks:
- Run current smoke suite.
- Run device viewport review.
- Confirm iOS signing/export path.
- Confirm privacy/crash reporting status.
- Decide whether beta backend mode stays hybrid local-authoritative.
- Confirm whether Social Highlights is disabled, sandboxed, or internal-only for first beta.

Exit:
- build exports
- smoke tests pass except known documented fallbacks
- no gameplay blocker remains
- Social Highlights cannot accidentally post to real player channels before credentials/policies are ready

## v1 After MVP

### Async Formats

Prioritize:
1. Race
2. Stage Race
3. Miss-N-Out
4. CTF
5. Hidden CTF

Remaining tasks:
- tighten scoring and record storage
- ensure each format has a map eligibility rule
- ensure each format has clear pre-match copy
- define which formats can generate Social Highlights

### Progression And Economy

Keep out of MVP unless needed for beta framing.

Remaining tasks:
- rank write safety
- honey/wax clarity
- battle pass/swarm pass copy
- paid entry gates only after backend confidence
- decide whether Social Highlight sharing earns progression later

### Content And Feel

Remaining tasks:
- final hive/unit/lane polish
- sound pass
- vibration pass
- mode-specific celebration/loss feedback
- bot personality tuning
- Social Highlight video framing, CTA overlay, and thumbnail treatment

### Premium Arena Polish And Lane Hierarchy

Current direction:
- Build premium battlefield presentation through render-only changes.
- Do not change gameplay, sim state, OpsState, SimState, pathing, targeting, ownership, lane geometry, combat, networking, PvP hashes, or balance.
- Preserve faction color readability and lane clarity.

Arena story props:
- Use Swarmfront-specific props rather than generic sci-fi clutter:
  - destroyed bee husk clusters
  - destroyed drone wrecks
  - abandoned hive fragments
  - old tower foundations
  - cable bundles/exposed conduits
  - cracked tech floor plates or soft glow pools
- Keep no more than 3-5 atmospheric story props visible on screen at once.
- Props should be noticeable in screenshots but fade from conscious attention during gameplay.
- Placement must use the existing arena polish manifest/policy before any sprite placement.

Lane Visual Hierarchy Prototype:
- Uncontested lanes should feel embedded in the arena floor.
- Contested lanes should visually lift above the floor.
- Start with three render-only states:
  - embedded
  - active
  - contested
- Cache lane visual profiles and update only when lane render inputs change.
- Tween profile changes over roughly 0.20 seconds.
- No particles in the first pass; if pulse is used, keep it cheap and limited to currently pulsing lanes.

Next implementation order:
1. Inspect `lane_renderer.gd` and identify the smallest safe insertion point for cached visual profiles.
2. Add the feature flag `LANE_VISUAL_HIERARCHY_ENABLED`, defaulting safe for export.
3. Implement profile derivation for embedded/active/contested without changing lane geometry or sim state.
4. Add smoke tests proving profile changes do not mutate gameplay state or recreate lane nodes unnecessarily.
5. Wait for actual arena prop sprites before adding prop manifest entries or placement.

## Known Technical Risks

- `main_menu.gd` is too large and mixes launch flow, dashboard, async, store, and mode selection.
- Some UI smoke tests cannot preload main menu cleanly without autoload setup.
- Current broad worktree is dirty; future commits should be smaller and grouped by feature.
- Headless Godot check previously exited non-zero on known `RANK_TRANSPORT_FALLBACK connect_timeout`.
- Social video rendering requires graphics-capable workers; dummy headless rendering is not enough.
- Instagram and TikTok posting may be gated by platform review, account type, and API restrictions.
- Social posting creates moderation, privacy, retention, and takedown requirements even if game replays are not HIPAA-sensitive.

## Suggested Next Work Block

1. Run a focused gameplay soak on current public maps.
2. Fix only visible hitches or deterministic movement issues.
3. Finish map/mode eligibility smoke tests.
4. Do a menu cleanup pass around Free Roll, mode launch, and the new Social tab.
5. Decide the beta posture for Social Highlights: off, sandbox-only, or official-channel-only.
6. Plan render infrastructure: graphics-capable worker, storage/CDN, job queue, and credentials.
7. Commit in coherent chunks:
   - gameplay polish
   - map/mode rules
   - menu cleanup
   - Social Highlights infrastructure
   - docs/tests
