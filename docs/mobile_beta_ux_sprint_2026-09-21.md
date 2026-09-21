# Mobile beta UX sprint — September 21, 2026

Status: Campaign/Jukebox split approved; 25-level pilot implemented on `codex/single-player-campaign`; physical-phone validation pending.
Progression policy: a completed attempt, win or loss, unlocks the next level in both entry routes.

Current pass: arena menu/header/footer proportions implemented for review, with
quit confirmation and ad links saved until results. See the
[match layout implementation and validation](match_chrome_2026-09-21.md).
Review proportions and phone safe areas before the floor-art pass; paid exit
settlement still requires integration validation against the authoritative service.

## Current priority: floor, then hive art and in-game VFX/UX

Owner direction after the scale and selection passes: settle the floor first,
then improve hive artwork and its power/lane indicators, followed by growth,
shrinkage, pressure and related effects. The effects should have a polished,
premium finish. This explicitly extends arena visual finish beyond floor art.

Recommended review order (visual direction proposed, not yet approved):

1. Compare the current floor with a restrained graphite/metal treatment using
   the same camera, hive sizes, and gameplay samples. Keep the center quiet,
   reduce fine circuit lines that resemble lanes, and use subtle material detail
   and contact shadows for depth. Assess the actual floor material rather than
   relying on the current heavy dark veil. Review idle, selected and crowded states.
2. Settle one hive's artwork and indicator arrangement across all three tiers.
   Keep power immediately readable in a stable badge; distinguish available and
   occupied lane slots by shape/fill, and preserve existing slot semantics.
   Establish core, shell, port and ground-contact locations before final animation.
3. Finish tier-change effects: deliberate charge/reveal/settle for growth;
   controlled collapse/vent/settle for shrinkage. Power and lane information must
   stay readable and accurately represent canonical state throughout transitions.
4. Finish pressure, selection and capture effects using the same materials and
   lighting. Distinguish ongoing attack, critical pressure, tier loss and capture;
   retain current trigger rules. Avoid opaque plumes, persistent flashing, or
   effects that hide units and neighboring hives.
5. Review overlapping effects in a dense match on both phone platforms, including
   reduced motion and performance, before broad menu migration.

First deliverable: floor comparison in context. Then use one complete hive with
all its states as the reference for wider art/effects work. This avoids polishing
effects against artwork or indicator positions that will immediately change.

## Outcome

Make Swarmfront comfortable to read and navigate on iPhone and Android, finish
combat readability and arena presentation, and give Jukebox, times, records,
settings, and game modes a coherent place in the product.

The owner is open to changing the layout substantially. Preserve recognizable
Swarmfront identity without treating the current arrangement as a constraint.
Minimize rework by deciding content and navigation before final screen layouts,
validating shared sizing before migrating screens, and finishing arena art after
combat information and available battlefield space are settled.

Planning baseline: unified mobile source `c758b75`, branch
`codex/unified-mobile-release-20260918`. The owner reports beta versions for both
platforms. Record the actual tested build and device when collecting new evidence;
older release notes do not establish current installation or store status.

## Dependency order

| Order | Work package | Deliverable and completion condition | Depends on |
| --- | --- | --- | --- |
| 1 | Product decisions and screen inventory | Prioritized beta issues, complete route inventory, agreed Jukebox/records/settings responsibilities, beta mode shortlist, and proposed navigation map. Every feature has a destination and a beta/later decision. | Owner discussion and current beta inspection |
| 2 | Shared readability and layout foundation | Actual-size prototypes of home, a dense Jukebox/records screen, and arena HUD; established type, touch, spacing, safe-area, scrolling, and Back behavior. Validate on both phone platforms before broad migration. | 1 |
| 3 | Remaining combat readability and arena layout | Resolve the owner's concrete complaints; settle information priority, labels, routes, selection, HUD/footer space, and camera fit. Dense gameplay remains readable and gestures remain correct. | 2; combat feedback from 1 |
| 4 | Arena visual finish | Adjust floor, contrast, decorative detail, visual separation, and HUD surfaces around the accepted battlefield layout. Early, crowded, selected, and late-match states pass visual review without obscuring play. | 3 |
| 5 | Main menu and complete match journey | Implement the chosen home/navigation layout and carry the shared components through mode selection, Jukebox, setup/lobby, loading, pause, results, records, and replay entry. A player can choose, play, understand a result, and return or retry without navigation ambiguity. | 1–3; shared components from 2 |
| 6 | Remaining menus and exceptional states | Migrate every remaining reachable player surface, including nested dialogs. Complete the route checklist below; no essential text relies on small legacy styling. | 5 establishes the final shell and reusable patterns |
| 7 | Integrated phone review and beta handoff | Verify the complete journeys on named iPhone and Android devices, close blocking readability/navigation/input defects, and record candidate identity plus outstanding issues. | 4–6 |

Execute in this order by default. Package 5 depends on stable arena geometry and
shared components, not on decorative art completion; do not let an asset delay
hold up menu work. Prototype review in package 2 is intentionally cheap and does
not constitute a first implementation pass over every screen.

Level redesign dependency (owner clarification, September 21): most current maps
will be replaced or retired, with only some surviving. Treat the 25-level pilot
as temporary content. Continue reusable UI and progression work; use representative
replacement maps to validate battlefield fit before final arena polish. Finalize
the shipping catalog before campaign sequencing, encounter balance and stinger
time calibration. Plan retired-level record preservation and unlock/bookmark
migration as part of the catalog replacement, before the integrated beta handoff.

## Today: kickoff and decisions

- [x] Establish the single-player direction: the owner accepts curated campaign
  progression, early bot variety, attempt-based advancement, time-based stingers,
  a small initial campaign, and shared challenge record identities.
- [x] Implement the approved navigation: Campaign on main; Jukebox as a
  secondary bot/difficulty/map selector under Dashboard or Garage, resolving to
  the same campaign levels and leaderboards.
- [ ] Inspect the current beta's primary journeys and capture a baseline. Inventory
  live routes, including script-created dialogs; scene files alone are incomplete.
- [ ] Clarify what “times, records, options” includes: duration, timing rules,
  personal bests, leaderboards, match setup, and/or general settings.
- [ ] Choose the main menu's primary player goal and draft the destination map.
- [ ] Decide the beta mode shortlist and unresolved record/setup semantics before
  designing the detailed selectors and result screens.
- [ ] Prepare actual-size layout studies for home, Jukebox/records, and arena HUD.
- [ ] After the Jukebox/product discussion, collect the owner's top two or three
  remaining combat readability problems, with device and situation. Distinguish
  text size, visual ambiguity, touch difficulty, and decorative clutter.

The Campaign/Jukebox foundation is implemented. Remaining sprint dates and
implementation estimates follow the issue inventory and mode scope decision; new game modes are
not silently bundled into a UI polish estimate.

## Product discussion: decide before designing screens

### Home and navigation

Approved direction: give Campaign a direct main-menu button and move Jukebox
to Dashboard/Garage as a secondary single-player entry. Campaign offers Continue
and guided progression; Jukebox offers deliberate bot/difficulty/map selection.
Both enter the same defined challenges. This replaces the earlier proposal to
make Jukebox itself the primary single-player hub.

Keep fewer, larger main-menu destinations and a compact player summary. Place
detailed progression, store, and community content in their own destinations.
Use Dashboard → Jukebox. The current Garage remains a cosmetic customization workspace.

Compare this with a mode-first home using a small set of large choices. Evaluate
both by time to the intended activity and physical readability. Keep branding,
but allow its footprint, button shapes, grid, and bottom navigation to change.
Do not lock new names or the number of tabs until the destination map is settled.

### Jukebox, times, records, and options

Accepted direction, September 21: continuous campaign progression through fixed
levels, with automatic map/variant, bot personality, and difficulty selection,
per-level leaderboards, and time-based stingers. Discuss and settle the
single-player flow first; combat feedback follows. The latest owner proposal
places Campaign on main and makes Jukebox a secondary route to those same levels.
Players following Campaign encounter the bots without configuring every run.

Content ambition: roughly 150–250 map experiences derived from 50–60 maps.
The owner accepted shorter curated chapters introducing the five personalities
early, replacing the initial suggestion to finish every map against one easy bot
before meeting the next. Turtle is an illustrative first opponent, not an
established easiest personality. At 250 experiences,
five bots and the three documented tiers, the full product is 3,750 challenges.
That count measures combinations, not proven distinct or balanced experiences.

Accepted direction (pilot implemented; encounter and time tuning pending):

- Keep the fixed-level campaign and per-level records; introduce all five
  personalities within an initial curated set instead of delaying the second
  personality until level 251. Consider short opponent-focused chapters followed
  by mixed challenges and later harder rematches.
- Order difficulty by the complete encounter, including map and starting
  conditions. A personality is a strategic style, not a universal difficulty rank.
- Prototype 20–30 curated levels using existing content to assess pacing, bot
  distinction, and continuation before committing to the full map/variant factory.
- Award one stinger for winning, with two higher awards for calibrated time
  targets. A completed attempt advances the campaign; faster wins give replay goals.
  Thresholds need playtesting per challenge, especially for defensive opponents.
- Make Continue the Campaign hub's primary action. Results show the outcome/reward briefly
  and offer Next prominently, plus Retry and a visible exit. Decide whether actual
  automatic advancement is desired; do not assume an uncancellable countdown.
  Preserve progress so returning players resume without repeating setup.
- Show the opponent's name/personality in the level presentation. Campaign
  selects the configuration; Jukebox lets the player select an existing challenge
  through bot, difficulty, and map/variant choices. Entering through Jukebox does
  not by itself make a run practice-only or change record eligibility.
- Give each challenge a stable identity and frozen comparison conditions: map
  revision, starting state, roster, bot policy revision/tier, randomness policy,
  rules, allowed buffs/loadout, and timing/scoring rules. Displayed level number
  is its position, not its database identity. Future reordering must not move
  records to different encounters.
- Decide how changed bots/maps/rules create new record revisions and preserve
  historical results; never silently compare different conditions. Reuse the
  existing result authority and verification contracts. Automatic configuration
  simplifies the player's choice but does not eliminate record bookkeeping.

### Campaign and Jukebox share one challenge catalog

Approved contract for the new split:

- Campaign selects a challenge by progression order. Jukebox filters the same
  catalog by bot, difficulty, and map/variant, then shows the matching campaign
  level, stinger targets, personal best, and leaderboard before Play.
- Both routes launch the identical challenge definition and revision, apply the
  same verification/eligibility rules, and record through the same owning state
  and service systems. No separate Jukebox record pool or duplicated definitions.
- Catalog entries must match the full encounter. Map/bot/difficulty alone may be
  ambiguous if variants, starting conditions, or rules differ; expose the variant
  or matching level choice where needed rather than silently choosing one.
- A curated campaign may omit combinations. Offer only combinations with authored
  campaign levels for this mode; constrain dependent choices or explain absence.
  Do not generate thousands of mandatory campaign levels merely to fill a matrix.
  Unrestricted custom practice can be separately scoped later if desired.
- Confirmed access policy: level 1 starts open. Completing an unlocked level,
  whether a win or loss, opens the next level in both Campaign and Jukebox.
  Quitting or a no-contest does not unlock. Locked levels can be inspected.
  Losses earn neither PB times nor stingers; prior winning records remain intact.
  Campaign Continue remembers the next level after a completed attempt. Jukebox
  uses the same unlocks and records without displacing the Campaign bookmark.
- Share per-level completion, stingers, and best times across entry
  routes; awarding the same achievement twice must not duplicate rewards.
- Preserve return context: both result screens offer Next and Retry, plus return
  to the originating hub and retained selection. Jukebox does not move Campaign
  Continue. Both retain a visible exit.

Pilot: 25 authored challenges using five existing maps, all five bot personalities,
and three tiers, with one-tap Next and Retry. Open validation: encounter ordering,
bot difficulty, and provisional per-challenge stinger targets on real phones.
Campaign progression, saved completion/rewards, and challenge record identity are
functional scope beyond visual polish. Estimate them separately after these
contracts are settled. The owner has now authorized implementation.

See [Campaign pilot implementation contract](campaign_pilot_2026-09-21.md) for
ownership, persistence, fixed challenge conditions, validation, and limitations.

The pre-pilot code presented Jukebox as “browse maps / chase records,” with
map categories and weekly, monthly, season, and all-time board periods. Treat
that as the starting implementation, not a decision that all of it belongs on
one screen.

Decide these together:

| Topic | Decision needed before layout | Resulting UI requirement |
| --- | --- | --- |
| Campaign/Jukebox roles | Campaign is the approved main-menu entry; Jukebox selects matching campaign challenges from a secondary destination | Guided Continue path plus manual selection sharing levels and records |
| Times | Which durations/limits are selectable, what starts/stops the clock, and how are ties/failures represented? | Consistent setup copy, HUD clock, results, and comparison labels |
| Records | Personal best, friends/Hive, global, seasonal; which belong in beta? | Agreed summary, board filters, empty states, and navigation |
| Comparable runs | Which map/rules version, bot setup, buffs, difficulty, and other options define record eligibility? | Explain eligibility before Play and identify it in results |
| Setup options | Which are frequent choices and which belong behind advanced setup? | Short default path; readable controls for optional detail |
| General settings | Which audio, haptic, readability, accessibility, account, and support controls actually exist or are desired? | Separate persistent preferences from match configuration |
| Return loop | Retry the same challenge, change map/options, inspect records, or return home? | Results actions preserve appropriate selections and context |

Audit the existing timing, eligibility, record stores, and service contracts before
promising behavior. Public verified results and local personal records must retain
their existing authority boundaries. Any newly requested scoring, timing,
eligibility, persistence, or historical-record migration is a separately scoped
implementation item after the product decision. Merely moving a control does not
authorize changing its rule.

### Modes and player expectations

Separate three concepts in both discussion and navigation: the activity a player
wants, the rules used in a match, and the format/roster used to play it. Avoid
turning every combination into a separate home-screen button.

Current configuration documentation distinguishes rosters (`1V1`, `2V2`,
`3P_FFA`, `4P_FFA`) from rules (`STAGE_RACE`, `CAPTURE_FLAG`,
`HIDDEN_CAPTURE_FLAG`, `TIMED_RACE`, `MISS_N_OUT`). Inventory actual beta access
and readiness; code or documentation presence alone does not mean a mode ships.

Use the following as discussion hypotheses, not claims of established player
demand or commitments to build:

- Immediate play: a clear, low-effort path into a match.
- Learn/practice: tutorials and a forgiving way to experiment against bots.
- Competitive play: understandable opponent, stakes, ranking, and result status.
- Play with friends: invitation/private-match and rematch expectations.
- Chase a time or record: repeatable challenges with comparable conditions.
- Variety: daily/weekly challenges, staged runs, or elimination formats.
- Larger additions to consider later: survival/endless, cooperative objectives,
  campaign/progression challenges, and party/chaos variants.

Score each candidate by player value, clarity, existing implementation, testing
cost, backend/record dependencies, and whether it splits a small beta matchmaking
population. Select a small beta set, distinguish later candidates, and keep
unsupported promises out of the navigation. Before asserting market expectations,
add a focused current comparable-game review and ask beta testers what they tried
to find; neither research nor demand validation is complete in this planning pass.

## Complete UI coverage checklist

For each reachable surface, track: route, primary task, smallest-device issue,
component dependencies, revised layout, iPhone evidence, Android evidence, and
status. This is the seed inventory; expand it from runtime navigation.

- Home, player summary, primary navigation, and loading cover.
- Free Roll/Play hub, roster/rules selectors, friend invitations, VS setup/lobbies,
  and pre-match prompts/countdown.
- Jukebox map browser/preview, categories, setup controls, boards, time/record
  details, and return from a completed run.
- Arena HUD, buffs/loadout, timer/power information, pause/exit, tutorial messages,
  result overlay, retry/rematch, and return navigation.
- Dashboard/profile/settings, match history, statistics/analysis, replay entry,
  rank/leaderboards, achievements, Garage, and Buffs.
- Hive/community, browse/create/join/invite flows, member controls, and nested dialogs.
- Store, pass/progression screens, tournaments/contests, and any beta-visible
  money-entry/status surfaces. Preserve current availability gates.
- Onboarding/guide, support/account flows, and confirmations.
- Shared loading, empty, offline, unavailable/locked, pending, error, and retry
  states; long names, large numbers, longer copy, and scrolling.

## Rework prevention and acceptance

1. Reuse and complete `UITypography` and the existing UX standard rather than
   creating a second styling system. Establish physical readability on devices;
   authored font sizes and the existing 64-unit touch baseline are not proof.
2. Validate the proposed type scale against the densest representative screen
   before applying it everywhere. Reduce simultaneous content or use scrolling
   and detail views when needed; do not shrink essential text to preserve a grid.
3. Settle navigation, labels, settings semantics, and record scope before finishing
   home/Jukebox/results. Reuse common buttons, list rows, frames, and dialogs.
4. Settle combat information and HUD/footer geometry before final arena decoration.
   Preserve menu/ad/power-bar separation, safe areas, visible controls, and the
   screen-to-world input transform established by the earlier space pass.
5. Review at named device sizes on both platforms during package 2, after the
   combat change, and after the primary journey. Final device QA confirms the
   integrated result instead of discovering the basic scale for the first time.
6. Keep OpsState/SimState as the only gameplay authority. Presentation reads
   canonical state and emits intents. No layout task changes map topology,
   balance, input rules, scoring, economy, or enabled modes by implication.
7. Use focused route/layout tests and the applicable readiness gates for actual
   implementation changes. Combat changes also verify picking, lane grabs,
   friendly commands/enemy inspection, and unchanged authoritative state during
   presentation-only resize/inspection. Assess arena performance on devices.
8. The final screen inventory has no unreviewed reachable menus or nested dialogs;
   primary actions and escape controls remain readable, reachable, and unclipped.
   Separate implementation completion from physical-device validation.

## References

- [Unified mobile baseline](unified_mobile_release.md)
- [UX standard](ui/UX_MENU_VISUALS_BIBLE.md)
- [UI adoption/debt snapshot](ui/SWARMFRONT_UI_IMPLEMENTATION_STATUS.md)
- [Combat readability pass](planning_import/COMBAT_READABILITY_PASS_2026_09_10.md)
- [Battlefield space pass](planning_import/HUD_SPACE_PASS_2026_09_10.md)
- [Lane/input validation follow-up](planning_import/LANE_GRAB_VALIDATION_2026_09_14.md)
- [Mode and roster configuration](player_config_matrix.md)
