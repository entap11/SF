# Swarmfront v1 Launch Worklist (2026-03-09)

This is the current working list of major non-MVP projects and the recommended execution order that minimizes implementation friction.

## Recommended Order

### 1. Gameplay Safety Rails
Goal: reduce edge-case breakage across all modes before layering more content.

Tasks:
- Auto-substitute queued buffs when the drawn map does not contain the required tower, barracks, or other target structure.
- Add mode/map validation so invalid combinations fail early and clearly.
- Continue lane-occlusion tuning until gameplay and visuals match tightly enough on real maps.

Why first:
- This work reduces cross-mode bugs everywhere.
- It lowers downstream debugging cost for every later feature.

### 2. Next Game Type(s)
Goal: add new content on the same launch spine already proven by CTF.

Tasks:
- Build the next game type on the direct-launch mode spine used for CTF.
- Reuse current menu, routing, bot, and async patterns wherever possible.
- Prefer rule toggles over one-off forks when possible.

Why second:
- This is the lowest-friction content expansion path right now.
- The recent CTF work gives a stable implementation pattern to copy.

### 3. Battle Pass and Economy Finalization
Goal: move current economy wiring from scaffolding into productized v1 behavior.

Tasks:
- Replace placeholder reward generation with final reward tables.
- Finalize nectar sink logic and reward pacing.
- Finish concrete redemption hooks for:
  - bundle tokens
  - analytics credits
  - ad-free rewards

Why third:
- Most of the plumbing already exists.
- The remaining work is mostly tuning, product definition, and redemption behavior.

### 4. Contest and Tournament Layer
Goal: convert current prize and ticket plumbing into a real event layer.

Tasks:
- Ship exclusive async contests using the current access-ticket model.
- Add tournament scaffolding on top of the same entitlement path.
- Defer golden-ticket expansion until the tournament layer is stable.

Why fourth:
- This depends on economy and reward definitions being more concrete.
- It adds more operational and UI complexity than the first three projects.

## CTF Mode Status

### Parked as Good for Now
- PvP Capture the Flag works.
- PvP Hidden CTF works.
- Async Capture the Flag works.
- Async Hidden Flag works.
- Direct menu flow works.
- Bot activation works.
- Hidden-flag move works.
- Mirrored and random flag assignment works.
- Lane occlusion is enforced in gameplay instead of being only visual.

### Remaining for v1 Launch
These are important, but they are not worth blocking on before moving to the next major project.

1. Curated CTF map pool
- Stop relying on fallback test maps.
- Tag which maps are valid for CTF versus Hidden CTF.

2. CTF-specific bot behavior
- Teach the bot to value flag defense and flag pressure, not just generic lane play.

3. Hidden-flag UX polish
- Improve pre-match selection clarity.
- Improve reveal and moved-flag feedback.

4. Future variants
- Fog of war variants.
- Additional move-rule variants.
- These are later v1 polish or v2 candidates, not immediate blockers.

## 50,000-Foot v1 Pillars

These are the larger product pillars that still need to exist for v1 launch, independent of the lower-friction execution order above.

### 1. Garage and Customization Hub
Goal: give players a home for cosmetic expression, preview, and loadout control.

Scope:
- Build a garage where players can inspect and equip:
  - units
  - hives
  - lanes
  - power bars
  - floor skins
  - VFX add-ons
- Use the garage as the place where players choose their in-game cosmetic loadout.
- Add a 360 viewer for high-value visual objects such as:
  - hives
  - units
  - towers
  - barracks

Why it matters:
- This is the main cosmetic ownership and expression surface.
- It supports monetization, identity, and player attachment.

### 2. Contest and All-Time Leaderboard Layer
Goal: let players grind specific maps, bots, and challenges for permanent rank and recognition.

Scope:
- Add map-specific and contest-specific leaderboards such as:
  - fastest solve on a given map
  - best performance against a given bot
  - top three and all-time records
- Support a map jukebox or map-select surface so players can intentionally practice or grind a specific scenario.
- Tie this system into:
  - achievements
  - badges
  - honey rewards

Why it matters:
- It gives strong replay value to individual maps.
- It creates mastery loops outside live PvP.

### 3. Advanced Metrics and AI Analytics
Goal: turn match data into player improvement tools and future paid product value.

Scope:
- Define the advanced metrics package:
  - which stats matter
  - how they help players improve
  - how they are presented
- Build game-by-game analytics packages that explain:
  - why the player won
  - why the player lost
  - what they could have done differently
- Support future packaging as:
  - bundle
  - package
  - subscription

Why it matters:
- This is both a retention feature and a differentiated product layer.
- It can become one of the clearest monetizable value props in the game.

### 4. Bot System Depth
Goal: ship multiple bots that feel human, distinct, and worth playing repeatedly.

Scope:
- Build at least 3 to 5 strong bot personalities.
- Create bots that differ in style, such as:
  - average player
  - overaggressive dangerous player
  - stronger strategic player
  - player-specific style emulations later
- Make bots react to player actions instead of just following static scripts.
- Add humanizing behavior:
  - reaction time limits
  - occasional missed obvious moves
  - attention limits when too much is happening

Why it matters:
- Strong bots improve solo retention and practice value.
- If bots feel human enough, the game remains compelling even when humans are not immediately available.

## Strategic Pillar Ranking

This ranking is based on launch leverage versus implementation cost, not just design appeal.

### Recommended Strategic Order

1. Bot system depth
2. Contest and all-time leaderboard layer
3. Garage and customization hub
4. Advanced metrics and AI analytics

### Rationale

#### 1. Bot System Depth
Leverage: Very high
Cost: High

Why it ranks first:
- Good bots improve the core game loop itself, not just the surrounding product.
- Bots support solo play, practice, testing, matchmaking backfill, and content modes.
- If human availability is thin, strong bots protect retention in a way the other pillars do not.

#### 2. Contest and All-Time Leaderboard Layer
Leverage: High
Cost: Medium

Why it ranks second:
- This creates replayable mastery loops on top of maps and bots you already have.
- It makes specific maps and scenarios sticky without requiring real-time concurrency.
- It pairs naturally with honey, badges, achievements, and future contest prizes.

#### 3. Garage and Customization Hub
Leverage: Medium-high
Cost: Medium-high

Why it ranks third:
- It is a major monetization and identity surface.
- It makes cosmetic ownership feel real and supports long-term product value.
- But it does not improve actual match quality as directly as better bots or replay loops do.

#### 4. Advanced Metrics and AI Analytics
Leverage: High long-term
Cost: High

Why it ranks fourth:
- Strategically, this could become one of the strongest premium products in the game.
- But it depends on cleaner telemetry, clearer stats definitions, and more product packaging work than the others.
- It is powerful, but it is not the fastest path to immediate launch-quality stickiness.

### Practical Read

If the question is “what most improves launch quality fastest,” the order is:
- bots
- leaderboard loops
- garage
- analytics

If the question is “what becomes the strongest premium differentiator later,” analytics rises, but not ahead of bots for launch.

## Pillar 1 Status and Next Steps (End of 2026-03-09)

### Pillar 1 Current State
- A real Jukebox scaffold exists on the main menu.
- The Jukebox uses actual maps from the live registry, not mock cards.
- The Jukebox can launch directly into a selected map.
- Leaderboard period tabs exist for:
  - Weekly
  - Monthly
  - Season
  - All Time
- Top 50 rows and a pinned "Your Best" row are scaffolded.
- "Scout Top Run" is present as a parked button, but disabled until replay and premium logic are ready.

### What Is Real Versus Stubbed

#### Real now
- Main menu entry point
- Jukebox panel shell
- Map catalog backed by actual map files
- Direct map launch from the Jukebox
- Category filtering
- Board periods and row layout shell

#### Still stubbed
- Leaderboard data persistence
- Run ingestion into the board
- Badge ownership transfer for top placements
- Scout / replay entitlement gating
- Clan / hive leaderboard views

### Recommended Next Steps for Tomorrow

#### 1. Make leaderboard data real
Goal: replace deterministic local placeholder rows with an actual local or service-backed board source.

Tasks:
- Add a dedicated leaderboard state/service layer for map boards.
- Define one canonical record format:
  - map_id
  - mode
  - period
  - player_id
  - handle
  - best_time_ms
  - updated_at
- Start with local authoritative storage if needed, but structure it to swap into the central service later.

#### 2. Wire run submission into the board
Goal: map runs should automatically post results into the correct board on completion.

Tasks:
- Define which run types count for the Jukebox boards first:
  - async stage race
  - async CTF
  - future map-vs-bot runs
- On valid run completion, submit:
  - map id
  - mode
  - player id
  - time
  - optional bot id
- Only keep best legal result per player per board slice.

#### 3. Tighten Jukebox UX
Goal: make the scaffold good enough to browse and use without confusion.

Tasks:
- Improve layout and spacing.
- Add a stronger map hero presentation.
- Make category labels and map suitability clearer.
- Keep the "Play Map" button sticky and obvious.

#### 4. Define badge rules now, even if not fully wired
Goal: lock the competitive scarcity logic before data starts to matter.

Tasks:
- Decide whether badges are Top 5 or Top 10.
- Make badge ownership live and transferable.
- Decide whether each period has its own badge or whether only All Time does.

### Recommended Morning Starting Point
Start with Step 1 and Step 2 together:
- build the leaderboard state/service layer
- then wire result ingestion from one run type first

Best first slice:
- async single-map timed boards

Reason:
- easiest to reason about
- lowest ambiguity
- strongest path to replacing the current stub data fast
