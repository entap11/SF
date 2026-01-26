# SwarmFront (SF) — v1 SYSTEM SPEC
Status: Core mechanics implemented and playable
Goal: Ship v1 playable + progression + UI wrapper, with future hooks for ENTaP

---

## 1. CORE GAME OBJECTS (LOCKED)

### 1.1 Hives
- Primary unit producers
- Primary ownership objects
- Only objects that:
  - Generate bees
  - Store mass
  - Win games

Hive Tiers
- Medium Hive
  - Flexible feeder
  - Easy to contest
- Large Hive
  - Lane anchor
  - Harder to flip
- Max Hive
  - Strategic gravity well
  - Losing one is decisive

Hive tiers change play behavior, not just numbers.

---

### 1.2 Lanes
- Persistent directional mass routes
- Carry bees between hives
- State-aware (direction, ownership, active/inactive)

Lane Rules
- Friendly -> Friendly = feed
- Friendly -> Enemy = attack
- Reversal = reverse flow
- Retraction:
  - Stops future spawns
  - Pulls bees currently in lane back to source hive
- Enemy lanes are not interactable

No cutting mechanic. Ever.

---

### 1.3 Towers (LOCKED HARD)

Placement Rules
- Towers exist only at junctions
- Each tower touches 3–5 hives
- Towers are organized into chains

Activation Rule
- Towers only activate when 100% of a chain is owned by one team
- Partial control = no effect

Function
- Towers only kill enemy bees
- No buffs
- No slows
- No generation
- No capture logic

---

## 2. TOWER TIERS (v1)

Tier I — Sentry
- Short range
- Fast fire rate
- Low damage
- Kills trickles, weak vs mass

Tier II — Gun Tower
- Medium range
- Moderate fire rate
- Medium damage
- Bleeds sustained pushes

Tier III — Bastion
- Long range
- Slow fire rate
- High damage
- Deletes clumps, defines no-go zones

Chain Scaling (ONLY AXIS)
- 3 towers: 1.0x fire rate
- 4 towers: 1.15x fire rate
- 5 towers: 1.35x fire rate

No range stacking
No damage stacking

---

## 3. BARRACKS
- Implemented and functional
- Spawn-modifying structure
- Obeys lane and hive rules
- No independent win condition

(Details OK to expand later; v1 behavior is sufficient.)

---

## 4. CONTROLS (LOCKED)
- Drag from hive -> target = feed/attack
- Drag opposite direction = reverse
- Retract = stop feed + pull bees back
- Enemy lanes/towers not clickable

Controls are single-verb, physics-consistent.

---

## 5. CORE LOOP (v1)
1. Match start
2. Player issues lane commands
3. Bees spawn and swarm
4. Towers activate only via chain control
5. Hive capture resolves match
6. End screen -> rematch / next

---

## 6. UI / UX (v1 TARGET)

### 6.1 Menus
- Play
- Async (stub OK)
- Buffs (view-only OK)
- Store (view-only OK)
- Clan/Hive (view-only OK)
- Settings

### 6.2 Dash
- Player snapshot
- XP / level
- League
- Recent match snippet or stats
- Clear entry into Play

Menus + Dash = next immediate milestone

---

## 7. PROGRESSION SYSTEMS

### 7.1 XP
- Earned per match
- Components:
  - Match completion
  - Win bonus
  - Light performance bonus

XP != skill
XP = progression & unlocks

### 7.2 Player Leagues / Tiers
- Bronze -> Silver -> Gold -> … -> Top
- Based on hidden MMR
- Seasonal structure (soft reset later)

### 7.3 Achievements vs Badges (LOCKED DEFINITIONS)

Achievements
- One-time checks
- Unlock once
- Examples:
  - First tower chain activation
  - Win 10 matches

Badges
- Equippable identity markers
- Often tiered (I–V)
- Visible to others
- Examples:
  - Brick by Brick
  - Keystone

Achievements may unlock badges, but they are not the same thing.

---

## 8. ASYNC (POST-MENU, v1.1)

Async Features
- Async menu
- Queue + play
- Results + leaderboard
- Monthly async contests (season ladder)

Async Buffs
- Restricted rule set
- Separate from live
- Pay-to-win capped or cosmetic-only initially

---

## 9. STORE / MONETIZATION (v1 SAFE)
- Cosmetics
- Skins
- Battle pass (simple track)
- Buff packs (minor, capped)

No wagering/betting in v1
(Separate compliance-heavy track)

---

## 10. CLANS (SF-FIRST, ENTaP-READY)

v1 Clan Features
- Create / join
- Clan chat (basic)
- Clan ladder
- Simple clan quests

Identity Hooks
- playerId
- clanId
- Optional entapProfileId

Clans must work in SF alone, but migrate cleanly to ENTaP.

---

## 11. STATS / ANALYTICS (v1 MINIMAL)
- Match history
- Win/loss
- Swarm usage
- Tower chain uptime
- Lane efficiency proxies

---

## 12. MATCH ANALYZER / AI (v1 LIGHT)
- Max 3 callouts per match
- Example:
  - Overfed lane X
  - Missed retraction under pressure
  - Lost tempo at tower chain Y

Player Style Assignment
- Lightweight labels
- Non-punitive
- Evolves later

---

## 13. ART & SPRITES (PARALLEL TRACK)

Art Timing
- Begins after menus + dash function
- Before async

Art Order
1. Silhouette pass
2. Functional color language
3. Default canonical skin
4. Skin system hooks (+1 alt skin)

Art never changes mechanics.

---

## 14. OUT OF SCOPE (DO NOT BLOCK v1)
- Betting / wagering
- Full ENTaP integration
- Deep AI coaching
- Advanced live ops
- Esports tooling

---

## 15. OPEN PARKING LOT (APPEND HERE)

Add anything we forgot without restructuring the doc.
