# Tutorial Controls v1

This is a dedicated replacement for the old sectioned tutorial. The shell launches it with `tutorial_launch_section = "controls_v1"` on `res://maps/tutorial/MAP_tutorial_controls_v1__1p.json`.

Old tutorial sections remain sandboxed behind their old explicit ids (`section1`, `section2`, `section3`) so they can be inspected or rolled back without competing with the new flow.

The controls tutorial bypasses normal prematch countdown/input lock. It starts the match immediately, then the tutorial controller owns sim pauses and prompts from the first highlighted hive.

## Map Anchors

- `start_hive`: P1 hive at `(2, 6)`.
- `neutral_hive`: neutral hive at `(8, 6)`.
- `friend_hive`: P1 hive at `(2, 17)`.
- `enemy_hive`: P2 hive at `(15, 17)`.

Runtime code resolves these anchors by owner and grid position because the strict map schema converts string ids to numeric ids.

The tutorial map includes a direct `start_hive` to `enemy_hive` candidate so the contested-lane lesson can teach attacking the same target from a second source.

The top-left player hive and red enemy hive both start at 25 power so each has a 3-lane budget during the multi-lane contest and swarm lessons.

Controls v1 disables autonomous enemy bot decisions; red counter-lanes are issued deterministically by the tutorial controller.

## Step Contracts

Each step owns a narrow contract: instruction copy, named source/target anchors, allowed input types, simulation pressure, and telemetry label.

| Step | Goal | Input |
| --- | --- | --- |
| `welcome` | Legacy contract retained for reference; the active tutorial now skips this and starts on `select_start_hive`. | none |
| `select_start_hive` | Tap the highlighted source hive. | tap |
| `feed_friend` | Tap the highlighted friendly destination hive to make a feed lane, then watch at least three bees land before the next prompt. | tap, wait |
| `reverse_feed` | Tap the current destination hive, then tap the original source hive to reverse the lane, then watch two bees land back at the original hive. | tap, wait |
| `cancel_lane_grab_throw` | Spotlight the source half of the friendly lane and require one continuous press-pull-release throw. The first valid press is routed directly to lane grab, including where the hive hit area overlaps the lane. | lane_grab_throw |
| `remake_friend_lane` | After the lane is removed, require remaking the lower-left to upper-left friendly lane before attack lessons continue. Both “tap source — tap destination” and drag are accepted; top-to-bottom remake is blocked. | tap, drag |
| `attack_enemy_hive` | Teach attacking from the friendly source hive to the enemy hive. Accept both “tap source — tap destination” and drag. | tap, drag |
| `contest_enemy_lane` | Let the first enemy attack lane run, have the enemy oppose it, and wait for three unit cancellations. | wait |
| `attack_enemy_from_start` | After three cancellations, pause and explain that equal lane pressure can continue indefinitely, then ask the player to attack the red hive from the original hive. | tap, drag |
| `attack_enemy_from_start_guided` | If the player waits ten seconds, pause and guide tap source, then tap red hive. | tap |
| `take_neutral_hive` | Ask the player to take the gray NPC hive from the original hive. | tap, drag |
| `attack_enemy_from_neutral` | Pause after gray capture, then ask the player to make an attack lane from gray to red. | tap, drag |
| `swarm_intro` | Pause and introduce repeating source-to-destination over an active lane. | tap_anywhere |
| `swarm_by_overlap` | Teach swarming over an active lane, then highlight another ready hive for each successive swarm until red is captured. The first swarm accepts any player hive; subsequent swarms follow the highlighted source. Tap/tap and drag are accepted throughout. | tap, drag |
| `wait_overlap_swarm_hit` | Let each swarm resolve, then immediately prompt the next hive if red is still hostile. | wait |
| `swarm_double_tap` | Mothballed and unreachable: retained for possible future gesture experiments, but lane overlap makes intent ambiguous. | lane_double_tap |
| `finish_fight` | Legacy free-play step, no longer reached by the active tutorial; the guided swarm sequence continues until capture. | none |
| `complete` | Mark the tutorial complete. | none |

## Chunk Plan

- Chunk 1: dedicated map, profile flags, tutorial launch id, controller shell, step contracts.
- Chunk 2: success detection and step advancement. Implemented with tap forwarding, lane intent polling, capture checks, retract detection, swarm packet/request detection, and profile completion.
- Chunk 3: input gating, spotlight/arrow polish, telemetry details. Implemented with step-local press gating, source/target focus rings, focus line, and `TUTORIAL_CONTROLS_INPUT_BLOCK` telemetry.
- Chunk 4: smoke coverage and tuning pass on real mobile builds. Added `scripts/dev/run_tutorial_controls_smoke.sh` to launch through the real tutorial entry, verify controller/overlay startup, check wrong-input blocking, drive each step through authoritative state changes, and confirm completion persistence.
- Chunk 5: recovery and mobile UX tuning. Shortened tutorial copy, made the prompt panel dynamically move away from focused hives/lanes, tuned focus ring/line sizing, added recovery guards for wrong selection, early hive capture, missing swarm lane, and unresolved match end logging.
- Chunk 6: paused step readouts. Each action step now pauses the sim before input, shows a larger readout explaining both the requested action and what it teaches, then hides the readout and resumes the sim on the first valid input for that step. Wait/free-play steps do not hold the sim.
- Chunk 7: oversized mobile text. The tutorial briefly used a tap-anywhere welcome gate, but that was removed because outside-window taps could confuse startup. Readout typography and panel sizing remain increased for phone readability.
- Chunk 8: first lane tap sequence. The first active lesson now pauses on a highlighted source hive, advances to a second paused prompt that highlights the friendly destination hive, and resumes the sim only after that destination tap creates the feed lane.
- Chunk 9: feed-lane breathing room. After the friendly destination tap, the sim stays unpaused and the tutorial waits for three actual arrivals at the destination hive before pausing for the reverse-lane lesson.
- Chunk 10: reverse-lane tap sequence. The reverse lesson now pauses on the current destination hive, then switches the prompt/highlight to the original source hive. After the reverse command, the sim runs until two actual arrivals land back at the original hive before pausing for lane cancel.
- Chunk 11: cancel-options, rebuild, and drag-attack lesson. This originally included double-tap-near-source; the live lesson now uses grab-throw while spotlighting only the source half of the friendly lane. Cancel waits for the lane pair to be fully inactive, then requires rebuilding the lower-left to upper-left friendly lane before the following attack prompt.
- Chunk 12: direct start and wet-noodle lane grab preview. The controls tutorial now opens directly on the highlighted source-hive lesson, and the grab-throw tension preview stays attached to the lane source while the destination end bends toward the drag point.
- Chunk 13: contested enemy lane lesson. After the drag attack, the red hive opposes the lane so units cancel each other. After three cancellations, the tutorial keeps the sim running and tells the player to attack from the original hive, with a ten-second paused fallback that guides source then target.
- Chunk 14: win-path swarm lesson. After the second red attack, the enemy opposes that lane too. The tutorial then teaches taking the gray hive from top-left, attacking red from gray, and swarming by repeating source-to-destination over the existing gray-red lane. The former follow-up double-tap lesson is mothballed.
- Chunk 15: startup and pacing pass. Controls v1 now skips normal prematch startup so the first highlighted hive is clickable immediately. Action-result transitions use a 4.5 second dwell before the next prompt appears, letting lane creation, captures, contests, and swarms breathe.
- Chunk 16: direction and contest fixes. Remaking the friendly lane is locked to lower-left source into upper-left destination, preventing accidental top-to-bottom lane use. The first cancellation lesson now pauses with explanatory copy after the cancellation count. Red starts with 3 lanes, has autonomous bot decisions disabled for controls v1, and immediately opposes the gray-to-red attack before swarm instruction begins.
- Chunk 17: direct lane-throw action gate. The cancel lesson no longer uses a dismiss-on-input readout or the double-tap shortcut. An animated hand and elastic lane shadow demonstrate the sideways pull, and the first valid press is constrained to the lane-grab input path so an overlapping hive hit cannot steal the gesture. The sim stays paused only until that valid press, then resumes for the pull/release and any retry; the constrained gesture ignores incidental structure overlap and uses a forgiving throw threshold.
- Chunk 18: completion and gesture reliability. The former red-half double-tap targeting remains in dormant code but is unreachable because overlapping lanes make source intent ambiguous. Friendly-lane remake explicitly guides and accepts tap/tap as well as drag. Tutorial completion is latched through match end so the dedicated congratulations screen appears, then automatically launches the existing easy-turtle 1v1 follow-up after a short countdown.
- Chunk 19: first-match onboarding reward. The first easy-turtle match after the controls tutorial ends on a one-time Welcome Pack screen. Opening it atomically grants two of every selectable Classic buff type, persists the claim, and returns to the main menu.

## First match: Simple Syrup

Completing Controls v1 automatically launches `res://maps/tutorial/MAP_simple_syrup__1p.json` against the existing easy Training Turtle bot. It remains a free, unranked practice 1v1 with the existing completion rewards.

The 18×28 board has seven hives: P1 at `(8.5, 24)`, P2 at `(8.5, 3)`, four neutral side hives at `(4, 18)`, `(13, 18)`, `(4, 9)`, and `(13, 9)`, and a shared neutral at `(8.5, 13.5)`. Both players start at 10 power; side neutrals start at 5 and the center starts at 10. No lanes start active and there are no walls.

The first match contains only ordinary hives: no towers, barracks, or structure slots.

The separate `res://maps/simple_syrup/MAP_simple_syrup__TB__1p.json` variant, **Simple Syrup (Structures)**, preserves this layout for regular 1v1 and async play. A tower at `(5, 13)` occupies the left center triangle, controlled by the two left-side hives and the center. A barracks at `(12, 14)` occupies the right center triangle, controlled by the two right-side hives and the center. Both positions are also authored as legal structure slots. This variant uses the ordinary structure-control rules, including neutral control while all three assigned hives remain neutral. Capturing the center alone does not grant either structure.

The follow-up launch clears previous match-randomizer metadata so starting seats and hive powers remain as authored. The tutorial handoff smoke check waits for Simple Syrup to load with seven hives, no structures, and no structure slots, beyond checking the bot-launch metadata.

## Pointer reliability — September 24, 2026

- Project tutorial highlights from the battlefield SubViewport into the HUD coordinate space. Lane-gesture constraints use the same projected space.
- Place prompts around the currently requested hive. Destination prompts use a compact layout so neither endpoint is covered by the panel or its Skip button; the swarm prompt leaves all three sources available.
- Keep source taps idempotent and prioritize the prompted hive over overlapping lanes. Reconcile the prompt with InputSystem's selection after release, including an abandoned drag; do not depend on a later frame copying selection into the simulation snapshot.
- Consume repeat presses and their releases while watching arrivals, contests, captures, swarms, and the existing post-action dwell. Show a short confirmation during these waits. Existing simulation rules and dwell durations are unchanged.
- Keep one pointer gesture active at a time, and release a tutorial-owned pause when the controller is hidden, including before the lane-throw lesson's first press.

`tools/tutorial_controls_input_regression_test.gd` exercises the controller with the real InputSystem and OpsState for mouse and touch retries, interrupted drags, duplicate commands, second-finger interference, and pause cleanup. `tools/tutorial_controls_pointer_smoke_test.gd` walks through the real shell and viewport input path through the final capture, without injecting lanes, arrivals, powers, ownership, or tutorial deadlines. It supports `--touch`, `--drag`, `--repeat-inputs`, and `--capture-dir=...`.

Run the full walkthrough in an isolated project/user directory with `application/config/use_custom_user_dir=true`; starting the tutorial updates profile progress. The existing `scripts/dev/run_tutorial_controls_smoke.sh` also checks completion and the follow-up match handoff.

The ending remains guided through repeated swarms: after each swarm resolves, rotate to another ready hive (gray → top-left → bottom-left, starting after whichever source the player used). Follow-up prompts keep simulation running so power and cooldowns recover. There is no extra 4.5-second dwell after a swarm and no free-play handoff before capture. If other hives are recharging, retain a live recharge prompt; count only accepted swarm requests, not failed taps.
