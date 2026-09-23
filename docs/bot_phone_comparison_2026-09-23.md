# Phone comparison with the owner — September 23, 2026

Status: proposed session and implementation requirements, not an uploaded or
installed TestFlight evaluation build. The owner plays through TestFlight and
will be available tomorrow. No phone playtest or human comparison has occurred.

The purpose is to compare a skilled human's choices with the five bot styles:
what gets expanded, supplied, reinforced, defended or abandoned, and when.
Win/loss is useful context. The owner's short explanations help distinguish a
deliberate sacrifice from a missed opportunity. One person's play provides
examples; it should not make every personality a copy of that person.

## First session

Start with one five-match block, all at medium difficulty in two-seat conquest.
If time permits, play the second block on a contrasting map. Keep human seat,
map setup, buffs and seed fixed within each block so opponent comparisons have
the same starting conditions. Do a mirrored-seat follow-up later if a decision
pattern appears dependent on starting position.

| Block | Proposed map | Opponent order | Human seat |
| --- | --- | --- | --- |
| A: five matches | Centerstrike CS3 | Greedy, Balancer, Turtle, Raider, Swarm Lord | 1 |
| B: optional five matches | No Man's Land Two Hubs | Swarm Lord, Raider, Turtle, Balancer, Greedy | 1 |

These are proposed evaluation encounters, not instructions to find arbitrary
opponents in the current Jukebox. CS3 uses
`MAP_centerstrike__CS3__1p`; Two Hubs uses
`MAP_nomansland__545__v18_two_hubs_each__1p`. Existing maps and ordinary simulation
commands are sufficient; the session must not alter published challenges or
campaign unlocks. CPU opponents should be identified as such.

After each match, note challenge, believable decisions and fun separately on a
1–5 scale. Add one short observation, ideally with an approximate match time:
“I sent the second attacker because…”, “I let that hive go because…”, or
“the bot should have taken this opening.” Normal play is preferable to narrating
every move, which would change timing and attention. A brief screen recording
can supplement the logs if an interface issue needs review.

## What the current code records

`MatchTelemetryCollector` saves match JSON under `user://matches`. It records
successful and rejected intents, their simulation timestamps, source and target,
actor seat and whether the actor is a CPU. Replay snapshots sample hives, lanes
and visible units every 500ms; units are capped at 220 per frame. Player metadata
contains bot style and tier. Existing derived metrics describe expansion,
aggression, lane use, tempo and responses to threats.

Those metrics are heuristic summaries, not measured thinking or a validated
human-likeness score. Response time also includes strategic choice and interface
handling. Sampled snapshots are useful context but are not exact pre-command
states. Bot decision events contain useful scheduling/policy details, but the
ordinary match collector does not currently persist the tournament's full
decision trace or policy observation/memory.
Some per-order source metrics use lightweight defaults; a zero in those fields
must not be interpreted as an observed empty hive. Use board data and verified
capture context when comparing individual choices.

The analysis should first show a few concrete side-by-side decisions with the
board and available alternatives, then summarize repeated patterns. Comparing
the bot's counterfactual choice at an exact human decision would require verified
reconstruction with the matching engine, rules and bot memory. That capability
must be checked before claiming an exact replay comparison.

## Preparation needed before phone play

The installed TestFlight version and build number have not been checked. Local
bot experiments use pinned Godot 4.7.1; older iOS documentation describes a
different custom engine. Neither document proves which engine or source is on
the phone. Record the actual distribution build, source revision and engine.

The normal Campaign/Jukebox route constrains encounters and can apply different
CPU tuning. An evaluation launch must use session setup, explicitly select the
retained medium Balancer human pilot, and record each effective bot profile and
seed. The other four personalities remain baseline policies. Verify one saved
match before asking the owner to play the full block.

An export path for the selected match JSON and the corresponding bot decisions
also needs to be verified on the distributed build. The Support Diagnostics
clipboard currently exports account/build/configuration diagnostics, not full
match replays. Do not ask the owner to play ten matches on the assumption that
these files can already be collected from TestFlight.

This preparation does not require faster production, movement or reactions.
The first session should compare the retained controllers; any later behavior
candidate should have a separate revision and repeat the same encounter setup.
