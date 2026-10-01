# Swarmfront Team Console — local preview

An SF-branded, disconnected content workspace. Uses the repository's canonical
logo and Iceland font, charcoal panels, honey-gold accents and map/quest cards.
No frameworks, remote fonts, service credentials or build step are required to view it.

## Open

From the project root:

```sh
python3 tools/dev-dashboard/serve.py
```

Open **http://127.0.0.1:8766**. The server binds only to loopback and serves this
folder. Browser network connections are blocked by its content security policy.
It has no write or publish endpoint. `--port` selects a different local port.

## Review flow

1. Open **Content calendar**. Use **Day**, **Week** or **Month** and choose a date.
2. Drag from the **Daily**, **Weekly** or **Contests** catalog. The **Add** button
   offers the same operation with a date form for keyboard and touch use.
3. Daily entries land on the selected day, weekly entries snap to Monday, monthly
   entries snap to the first. Drag an existing entry to move it without duplicating it.
4. **Use quest rotation** loads the repository's three-per-day plus four-weekly
   assignments into the selected week. Existing entries are preserved; duplicates
   and full quest periods are skipped. This may differ from the original rotation
   if the week already contains custom quest choices.
5. Click a scheduled entry to inspect or reschedule it, edit its underlying quest
   or map set, or remove it. Limits are three daily/four weekly quests per period.
6. **Drafts** reviews local content edits and the schedule. **Export draft bundle**
   downloads JSON with source hashes and `publishable: false`.

There are no recurring scheduler jobs. Each drop represents one local planned
period. Contests have a launch cadence; rolling async remains the rolling-cohort
family rather than becoming a different public contest scope. Daily Time Puzzle
periods explicitly show their missing server support. Gauntlet uses weekly
cadence and its existing 18-stage order.

Quest titles, reward amounts and objective targets are editable. Family/mode
filters remain attached. Contest map order and titles can be drafted; Gauntlet
stage composition remains read-only. Battlepath shows all 120 resolved levels,
three tracks, season dates and reward identities; quantity and Nectar requirement
edits are local drafts. Adding new reward types is outside this review slice.

Drafts persist in this browser's localStorage under
`swarmfront.team-console.drafts.v1`, separate from every game catalog and player
profile. Another browser/profile starts empty. Different tabs are not a shared
team editing session. Export a bundle to retain or hand off the work. Import and
shared editing will come with the publishing service, not an implicit live connection.

## Actual catalog sources

`data.js` is generated, not a hand-written mock:

- `platformQuestCatalog.ts`: 24 daily templates, 4 weeklies and nine weeks of
  the actual assignment rotation. The exporter uses a reference date for preview;
  it does not read or set a live quest activation date.
- `battle_pass_config.json` plus `battle_pass_config.gd`: 120 resolved reward
  levels exported by the actual Godot configuration code in an isolated temporary
  project, without autoloads. These are client configuration definitions, not
  proof of deployed progression/reward policy.
- `public_contest_content.gd` and `progressive_config.gd`: the existing Time Puzzle
  map lists and 18-stage Gauntlet sequence; async uses the same map pack convention.
- Nineteen referenced map JSON files: thumbnails plot their authored hive positions.
  They do not simulate lanes or claim to be full gameplay screenshots. Current
  referenced files reside in the future library and are labeled accordingly.
- Existing SF logo and Iceland font copied into `assets/` for a self-contained preview.

Source configuration says Season 1 ends October 1, 2026 UTC. The preview labels an
ended source season instead of inventing a new active season. Historical paid
contest fixtures are not presented as current live events.

Refresh the snapshot after source catalog changes:

```sh
python3 tools/dev-dashboard/generate.py --godot /usr/local/bin/godot
```

This uses the existing Rank-service `tsx` install to export quest definitions.
A nonfunctional loopback DATABASE_URL satisfies import-time configuration validation;
no database is opened. The generator writes only this preview's data and assets.
Map IDs must resolve uniquely, so missing/ambiguous source maps fail generation.

## Browser verification

Start the local server, then run with an available Playwright installation and Chrome:

```sh
SF_PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node tools/dev-dashboard/smoke.cjs
```

Optional variables: `SF_DASHBOARD_URL` (loopback only), `SF_DASHBOARD_ARTIFACTS`.
Tests use disposable browser contexts and do not change an existing user's drafts.

The smoke covers real drag/drop, moving an existing event, duplicate prevention,
Monday/month-start snapping, accessible Add, missing daily-period support labels,
25-quest week seeding, daily slot limits, quest/map/Battlepath edits, season date
validation, draft export/reload/discard, mobile overflow, browser isolation and
absence of external requests. Screenshots are written alongside the test export.

## Next implementation boundary

A calendar drop **does not activate content on its date** yet. To make that real:

1. Store validated content revisions and dated schedule entries behind team auth.
   Bind each schedule entry to a specific revision and map pack.
2. Validate period support, map hashes/client availability, quest variety and
   reward budgets; compare and preview changes before publishing a schedule.
3. Connect the existing contest publication APIs, add the quest schedule reader
   and Battlepath publication authority, and execute due entries idempotently.
4. Preserve already assigned quest manifests and existing contest attempts.
   Edits create future revisions; moving a published calendar card is not a
   silent rewrite of an active contest or a player's rewards.
5. Add execution status, failures/retries, audit history and future-entry cancellation.
   Define daily public Time Puzzle support before enabling that calendar option.

No beta deployment, game-rule change or service flag change is included here.
