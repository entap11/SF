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
| `swarm_intro` | Pause and introduce the two swarm methods. | tap_anywhere |
| `swarm_by_overlap` | Teach swarming over an active lane. All three player-owned hives are valid sources; both tap/tap and drag to the red hive are accepted. | tap, drag |
| `wait_overlap_swarm_hit` | Let the first swarm hit before continuing. | wait |
| `swarm_double_tap` | Teach double-tap swarm anywhere on the red/destination half of the middle or bottom lane while locking out the gray-to-red lane. | lane_double_tap |
| `finish_fight` | Finish the fight without prompts blocking play. | free_play |
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
- Chunk 11: cancel-options, rebuild, and drag-attack lesson. The old hold-only cancel prompt now teaches double-tap-near-source and grab-throw cancel options while spotlighting only the source half of the friendly lane. Cancel now waits for the lane pair to be fully inactive, then requires rebuilding the lower-left to upper-left friendly lane before the following drag-only attack prompt.
- Chunk 12: direct start and wet-noodle lane grab preview. The controls tutorial now opens directly on the highlighted source-hive lesson, and the grab-throw tension preview stays attached to the lane source while the destination end bends toward the drag point.
- Chunk 13: contested enemy lane lesson. After the drag attack, the red hive opposes the lane so units cancel each other. After three cancellations, the tutorial keeps the sim running and tells the player to attack from the original hive, with a ten-second paused fallback that guides source then target.
- Chunk 14: win-path swarm lesson. After the second red attack, the enemy opposes that lane too. The tutorial then teaches taking the gray hive from top-left, attacking red from gray, swarming by creating over the existing gray-red lane, and finally double-tap swarming only on the middle or bottom red lane.
- Chunk 15: startup and pacing pass. Controls v1 now skips normal prematch startup so the first highlighted hive is clickable immediately. Action-result transitions use a 4.5 second dwell before the next prompt appears, letting lane creation, captures, contests, and swarms breathe.
- Chunk 16: direction and contest fixes. Remaking the friendly lane is locked to lower-left source into upper-left destination, preventing accidental top-to-bottom lane use. The first cancellation lesson now pauses with explanatory copy after the cancellation count. Red starts with 3 lanes, has autonomous bot decisions disabled for controls v1, and immediately opposes the gray-to-red attack before swarm instruction begins.
- Chunk 17: direct lane-throw action gate. The cancel lesson no longer uses a dismiss-on-input readout or the double-tap shortcut. An animated hand and elastic lane shadow demonstrate the sideways pull, and the first valid press is constrained to the lane-grab input path so an overlapping hive hit cannot steal the gesture. The sim stays paused only until that valid press, then resumes for the pull/release and any retry; the constrained gesture ignores incidental structure overlap and uses a forgiving throw threshold.
- Chunk 18: completion and gesture reliability. Red-half swarm double taps use a generous screen-space lane target and bypass overlapping hive selection; friendly-lane remake explicitly guides and accepts tap/tap as well as drag. Tutorial completion is latched through match end so the dedicated congratulations screen appears, then automatically launches the existing easy-turtle 1v1 follow-up after a short countdown.
- Chunk 19: first-match onboarding reward. The first easy-turtle match after the controls tutorial ends on a one-time Welcome Pack screen. Opening it atomically grants two of every selectable Classic buff type, persists the claim, and returns to the main menu.
