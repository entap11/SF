# Simple Syrup phone bot comparison — September 28, 2026

Authorized scope: prepare and install a one- or two-game iPhone comparison on
the new seven-hive Simple Syrup map. First opponent: retained medium Balancer
human pilot; optional second opponent: medium Raider baseline. Human seat 1,
seed 9282026, ordinary two-seat conquest, fixed empty buff loadout.

Session setup owns the launch descriptor. OpsState owns seed/profile application
and gameplay. The playtest UI emits launch/return requests. Telemetry reads
public observations and records decisions; it never applies gameplay changes.
The pilot is enabled only for this explicit evaluation session. Bot policies,
production, movement, reaction delays, combat and capture rules are unchanged.
Campaign and Jukebox definitions/unlocks are not evaluation entry points.

This is a directly installed development build, not a TestFlight publication.
The source starts at cc9e7e1; the map is copied unchanged from 7e50220.
Other worktrees and their uncommitted changes remain independent.

Acceptance: both launch choices reach the correct map/roster/profile/seed;
standard commands and human-pilot delays remain intact; saved JSON includes
build/map identifiers, bot decision events, permitted observations, human
intents and sampled replay frames; exported files can be retrieved from the
paired iPhone. A partial recording is labeled incomplete. Game two is optional.

Evidence and the development app are under `SF/artifacts/bot-phone-2026-09-28/`.

## Installed checkpoint

Direct installation and foreground launch succeeded on the paired iPhone 16 Pro:
`com.matthew.swarmfront`, version 0.1.3, build 2026092801, Apple Development team
SH6675DXQ5. Installation updated the existing app; no uninstall or device-key
reset was performed. The exported and signed embedded game packages match.
The package contains the evaluation feature, dedicated start screen, unchanged
Simple Syrup map, and the full source fingerprint manifest.

Both launch choices pass the end-to-end smoke: seven hives, two active seats,
conquest, fixed seed, correct effective policy, legal human command, human
pre-command public observation, Balancer observation/plan memory, sampled board
frames, incomplete checkpoint, completed recording, and optional second game.
The existing bot runtime passes all 100 checks and the telemetry hook suite
passes. Source/import/export checks report no GDScript parse errors.

Initial checks caught the missing imported map alias and default profile reset;
both were corrected. A later rendered rerun exceeded its cold-start fixture
deadline; the wait is now bounded at 60 seconds. Headless Arena runs also emit
existing shader compiler and shutdown resource warnings, so they are not visual
acceptance evidence. The hub/result captures were inspected separately.

The campaign catalog's generated rules fingerprint was refreshed because its
generator hashes simulation source files, including the evaluation hooks. Level
definitions, unlocks and challenge parameters were not edited. The broader fast
release gate was started as additional coverage; its live outcome is retained
in `fast-gate.log`, independently of the focused playtest checks. This is not
an App Store/TestFlight release-readiness claim.

File retrieval from this app's device container was verified before installing.
Human playtest recordings have not yet been collected at this checkpoint. They
are atomically checkpointed every 15 seconds, saved at match end/return, and
labeled incomplete if interrupted. Retrieve them with:

```sh
python3 tools/collect_bot_phone_evaluation.py \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --output ../artifacts/bot-phone-2026-09-28/device-capture
```

The exported JSON contains personal match telemetry. Keep it local. Sampled
board frames are context, not an exact replay of every prior state; the explicit
human intent observations and Balancer choice witnesses identify their own
simulation times. No claim of improved human likeness follows from these checks.
