# Tutorial and first-session audit — September 17, 2026

The proposed sequence is a good direction: call sign → automatic tutorial → main menu welcome pack → accept and launch first bot match → first victory → ordinary play. The current implementation contains most of the individual pieces, but connects them in a different order and does not persist the whole journey.

This is an audit of the current `project/` working tree, including its existing bot changes. No gameplay code, tuning constants, or player saves were changed. Findings below distinguish source-confirmed behavior from design proposals. Git history shows Controls v1 arriving July 1, with subsequent July 17 and September 10 changes; it does not establish which model authored it.

## Current journey

| Stage | Source-confirmed behavior | Difference from intended experience |
| --- | --- | --- |
| Account setup | Call sign and age are required. Successful backend registration saves identity and emits the tutorial launch request. Debug builds can substitute an offline identity. | The intended automatic launch exists on successful submission. Release account-service failures still prevent entry. |
| Tutorial | Dedicated `controls_v1` four-hive scenario; autonomous opponent disabled; guided lanes, feeding, reversing, cancellation, contested attacks, neutral capture, and swarms. | The older three-section tutorial is retained for explicit sandbox use. Its buff and structure lessons are not part of Controls v1. |
| Tutorial completion | Congratulations overlay starts a six-second countdown, then launches a free, unranked practice 1v1. | Main menu and welcome pack are bypassed. |
| First opponent | “Training Turtle,” standard Turtle/easy configuration, on a 12-hive No Man's Land map under `_future`. | No onboarding-specific curve makes it progressively easier. The baseline policy still has ordinary time/board-sensitive behavior. |
| First-match rewards | A local victory attempts a 25-honey bonus and grants `ACH_FIRST_WIN`. Any outcome can offer the unclaimed welcome pack. | Honey depends on winning; buffs arrive after the match. |
| Welcome pack | Two of every selectable Classic buff type; opening calls the profile grant and returns to main menu. | No honey in this pack transaction; accepting it does not launch a match. |
| Later play | Normal modes are available. | No durable “first assisted match finished” milestone exists to enforce the intended one-time boundary. |

Primary paths: [account submission](../scripts/ui/onboarding/onboarding_panel.gd#L39), [menu launch](../scripts/ui/main_menu.gd#L2286), [follow-up configuration](../scripts/shell.gd#L1884), [reward handling](../scripts/arena.gd#L5851), [welcome claim](../scripts/profile/profile_manager.gd#L997), and [outcome screens](../scripts/ui/outcome_overlay.gd#L682).

## Changes to prioritize

**1. Persist the entire journey, then route from that progress on every boot.**

The menu initiates the tutorial from the account-submission signal. Its ordinary returning-player path does not resume onboarding, and both auto-launch checks accept `not_started` but reject `in_progress`. Controls v1 persists status/version, but starts at the first lesson each time. Follow-up eligibility lives in SceneTree metadata, which disappears on process exit. A quit during the lesson, completion countdown, first match, or unopened pack can strand the intended flow.

Use one canonical onboarding progress record, for example `tutorial_pending → tutorial_in_progress → welcome_pending → first_match_pending → first_match_in_progress → complete`. Identity remains the existing profile identity; this progress record is not a second game state. Store the tutorial revision, safe lesson checkpoint, welcome grant receipt, and first-match attempt ID. Resolve account identity before routing. Reconstruct checkpoints through simulation setup rather than restoring a lesson label onto an unrelated board.

Sources: [menu gate](../scripts/ui/main_menu.gd#L2286), [launch eligibility](../scripts/shell.gd#L398), [controller startup](../scripts/arena_helpers/tutorial_controls_controller.gd#L156), [profile persistence](../scripts/profile/profile_manager.gd#L1617).

**2. Put the pack in the main menu before the first match, with a recoverable claim.**

Show a focused welcome modal over the main menu, with one primary action such as **“Claim & Play Your First Match.”** Display the exact honey and buff contents. A successful claim advances to `first_match_pending`; only then launch the game. On failure, retain the modal and allow retry. On restart after a successful claim, resume the pending match without granting again.

The current buff claim protects against repeat calls and writes inventory plus its flag together in one profile save. However, `_save_profile()` does not return its disk error, so the claim can report success without durable persistence. Arena also returns to the menu regardless of claim success. Honey follows a separate authority-aware grant path. The intended combined package needs an account-scoped, versioned, idempotent grant receipt and a clear reconciliation path for partial failure. Do not represent separate honey and buff operations as one atomic transaction unless the economy authority actually provides that guarantee.

Use an explicit package manifest rather than “all selectable Classic buffs”: otherwise adding a catalog item silently changes what new accounts receive. Quantities remain TBD. I would start with honey sufficient for a useful first choice and a small, understandable selection of buffs, then balance the amounts against the economy.

Sources: [claim](../scripts/profile/profile_manager.gd#L997), [save](../scripts/profile/profile_manager.gd#L1641), [unconditional return](../scripts/arena.gd#L6370), [honey authority](../scripts/state/honey_progression_state.gd#L448).

**3. Make the first bot a dedicated onboarding configuration.**

The current easy Turtle is not a gradually weakening opponent. It also inherits future Turtle tuning, so unrelated bot improvements can change the new-player experience. Its defensive behavior makes a prolonged standoff a plausible risk; this audit has not measured novice win rate or match duration.

Proposed behavior, to calibrate with playtests:

- Opening: below-medium pressure, visible expansion, enough time for the player to establish lanes.
- Middle: gradually slower decisions, fewer coordinated attacks, and missed opportunities to reinforce threatened territory.
- Closing: fewer recaptures and counterattacks so the player can convert an advantage into conquest. Simply stopping new decisions is insufficient because existing lanes keep producing pressure.
- Additional easing if the player is falling behind, based on authoritative board state and simulation time. Do not increase difficulty again because the player starts succeeding.

Keep growth, damage, lane capacity, capture, and victory rules unchanged. All bot actions must use the ordinary simulation validation path. Bot schedule and memory belong in OpsState, matching the existing BotSystem architecture. An onboarding flag must be explicit in the match configuration and absent from every ordinary match.

A likely win is achievable; a literal guaranteed win is incompatible with unrestricted player inaction or self-defeating moves under unchanged rules. I recommend optimizing for a very high win rate among engaged beginners, with a kind loss/retry path. Treat a retry as the same unfinished onboarding encounter; after its first win, retire assistance permanently. If the requirement is exactly one attempt instead, a loss must end onboarding without claiming that a first win is guaranteed.

Sources: [follow-up roster](../scripts/shell.gd#L1884), [bot runtime](../scripts/systems/bot_system.gd#L24), [easy tier](../scripts/ops/ops_state.gd#L1750), [baseline policy](../scripts/bot/baseline_bot_policy.gd#L8).

**4. Tighten the tutorial around understanding and transfer to normal play.**

Keep the dedicated map, real player actions, authoritative completion observations, highlighting, tap/drag support, and visible lane-collision lesson. These are useful foundations.

Suggested revisions:

- Open with the objective: “Capture every enemy hive to win. Tap your highlighted hive to begin.” The current first prompt explains input without stating the overall goal.
- Consider teaching attack/capture before the full feed → reverse → cancel → rebuild sequence. It gives an immediate payoff; retain feeding and cancellation before the final challenge.
- Add brief explanations of power and the 10/25 lane-capacity thresholds, and the cost of sending a swarm. Do not let the final lesson imply swarming is a free repeat attack.
- Add one short buff activation lesson if the first match allows buffs. Use a tutorial-provided charge rather than consuming the welcome inventory before it is awarded. Keep detailed buff selection out of the first-session path.
- Defer towers/barracks to optional lessons, and choose a first-match setup that does not require unexplained structure mechanics. The current follow-up map has structure slots; pin its complete setup explicitly.
- Preserve time to see arrivals and collisions, but replace blanket waiting where the result is already clear. Nine ordinary transitions can each add 4.5 seconds, plus a five-second swarm intro: approximately 45.5 seconds of scheduled dwell before player reading/input and travel time.
- Provide a way to reread the swarm instruction instead of relying solely on its five-second auto-advance. Use concise verb-first copy and a small progress indicator.
- Check lane-grab transfer on a real phone. The tutorial supplies special source-half picking and forgiving gesture handling; a novice should not master the tutorial version and then fail the ordinary gesture.

Sources: [active lesson contracts](../scripts/arena_helpers/tutorial_controls_controller.gd#L121), [dwell routing](../scripts/arena_helpers/tutorial_controls_controller.gd#L610), [map](../maps/_future/nomansland/MAP_nomansland__444__v01_pinched_spine__1p.json), [controls specification](tutorial_controls_v1_spec.md).

**5. Make skip, completion, replay, and loss explicit outcomes.**

Skip currently records `skipped` and hides the overlay; it does not leave the tutorial board. Since the opponent is disabled, this can leave an unguided scenario. There is also a specific pause-cleanup risk: the lane-cancel step pauses with `_readout_waiting_for_input=false`, while `hide()` resumes only when that flag is true. Skipping before the first lane-grab press can therefore leave the simulation paused. Completion can also trigger from capturing the enemy hive at any step, bypassing later teaching requirements. That may be useful recovery behavior, but it is not evidence that the player performed every lesson.

Choose a deliberate skip route—my preference is welcome pack → first match, with skipped/completed tracked separately. Keep replay available as practice, without resetting the first-session milestones or unlocking repeat rewards. Separate the production entry point from `prepare_tutorial_controls_sandbox()`, which currently rewrites older tutorial statuses and onboarding flags on every tutorial launch.

Require the chosen core competencies for “tutorial completed,” or explicitly record an early-win fast path. On a first-match loss, show honest results and the chosen retry option. Keep the welcome gift independent of that result. The current pack can appear after defeat, whereas the honey bonus requires a win.

Sources: [skip](../scripts/arena_helpers/tutorial_controls_controller.gd#L1654), [completion shortcut](../scripts/arena_helpers/tutorial_controls_controller.gd#L497), [sandbox reset](../scripts/profile/profile_manager.gd#L1042), [pack eligibility](../scripts/arena.gd#L6349).

**6. Preserve a clean handoff into ordinary play.**

Use a clearly labeled bot opponent and an unranked match. Celebrate the victory, then return to the main menu with a clear ordinary-play action. Do not carry the onboarding easing, scripted tutorial opponent, or tutorial setup into subsequent matches. Decide explicitly which personal achievement/progression counters include this result; it should not distort competitive ratings or competitive records.

The current match already requests practice=true, ranked=false, economic=false. Retain those boundaries while reviewing downstream reward/record consumers. A first-win badge can still acknowledge the real conquest result. Suppress unrelated menu promotions until the welcome and first-match handoffs are settled; `_on_onboarding_done()` currently also calls the scholastic join CTA path.

## Validation and release criteria

Existing tests cover useful pieces: `tutorial_flow_smoke_test.gd` exercises the old three-section controllers; the Controls v1 shell smoke drives the active flow; `onboarding_backend_identity_success_smoke_test.gd` checks account submission; `buff_inventory_wiring_smoke_test.gd` checks pack quantities, duplicate claims, and reload; `outcome_overlay_smoke_test.gd` checks the current countdown/pack screens.

The Controls v1 smoke mixes real input gestures with injected lane changes, hive power/ownership changes, and forced swarm cleanup. A pass would establish wiring, not prove a novice can naturally finish or win the follow-up match. The outcome test explicitly expects the old order and must change with the proposed flow.

Audit execution used Godot 4.2 in an isolated project with a separate user-data directory. Account-registration success, buff-inventory wiring, and outcome-overlay tests all passed. The outcome-overlay test needed a longer process timeout than the initial 40-second attempt. The active Controls v1 run completed with **43 passing checks and 1 failing check**: `tutorial_controls_tree_meta_set` observed empty launch metadata after the test's fixed two-frame wait. The later tutorial-completion and easy-bot auto-launch checks passed. Replace the early frame-count assumption with an awaited launch-ready condition; this result alone does not establish a production auto-launch failure. The run also reported leaked objects/resources at shutdown, so it is not a clean release pass. Phone interaction and novice win rate were not validated. Logs are retained in [the audit artifacts](../artifacts/tutorial-onboarding-audit-2026-09-17/README.md).

Release checks should include:

1. Fresh release account → call sign/age → automatic tutorial, with backend failure/retry exercised separately from debug offline fallback.
2. Quit/restart at every durable milestone, plus app backgrounding during a prompt, gesture, countdown, match, and reward claim.
3. Double claim, retry after network failure, disk-save failure, account/device changes, and interrupted honey/buff reconciliation.
4. Skip and replay without stranded boards or duplicated rewards; explicit first-match loss, draw, abandonment, and retry behavior.
5. A complete run using only normal touch input and unmodified simulation outcomes, followed by a real first bot match.
6. Ordinary second match has no onboarding configuration; repeated seeds produce identical bot behavior under simulation stepping.
7. Phone readability, safe areas, lane overlap selection, gesture transfer, and interrupted touches on supported mobile platforms.

Measure tutorial start/completion/skip, time and failed attempts per lesson, resume events, pack displayed/claimed/failed, first-match start/result/duration, and entry into the next ordinary match. Existing step/block logs are a foundation, but a durable first-session funnel and novice outcome data are still needed. Suggested initial playtest targets—not measured results—are a roughly 2–3 minute tutorial, a roughly 2–4 minute first match, and at least 90–95% conquest wins among engaged first-time players.

Recommended implementation order: persisted routing and recovery; welcome claim and menu handoff; dedicated first-opponent behavior; tutorial copy/pacing/lesson changes; then complete device playtests and funnel measurement. Package amounts remain a separate economy decision.
