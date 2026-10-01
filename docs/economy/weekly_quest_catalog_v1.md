# Weekly quest catalog v1

Approved for local implementation on 2026-09-29. Not deployed or enabled for beta.

Offer these four together each Monday at 00:00 UTC. Ordinary daily play advances
weekly objectives at the same time; players may also complete weeklies independently.

| # | ID | Display name | Completion requirements |
|---|---|---|---|
| 1 | weekly_across_the_front | Across the Front | Complete 12 Standard 1v1 games, 8 FFA games, and 4 three-map async runs. |
| 2 | weekly_team_and_tactics | Team and Tactics | Complete 10 games of 2v2, 6 CTF games, and 2 five-map async runs. |
| 3 | weekly_async_expedition | Async Expedition | Complete 6 three-map async runs, 3 five-map async runs, 6 Standard 1v1 games, and 6 games of 2v2. |
| 4 | weekly_free_roll_tour | Free Roll Tour | Complete 1 three-map Free Roll Time Puzzle, 2 Gauntlet runs, 1 additional three-map entry in async play or a daily/weekly/monthly/seasonal contest, and 4 PvP games. |
|---|---:|
|---|---:|---:|
| 2 | 2 hours 54 minutes | 3 hours |
| 3 | 4 hours 6 minutes | 4 hours 15 minutes |
| 4 | 5 hours 18 minutes | 5 hours 30 minutes |
|---|---|---|
| 1 | 1, 13, 16 | 3 Standard 1v1, 2 games of 2v2, 1 FFA, and 1 three-map async run. |
| 2 | 6, 18, 20 | 2 games of 2v2, 3 CTF, and 1 three-map async run. |
| 3 | 5, 19, 22 | 2 Standard 1v1, 3 FFA, and 1 three-map async run. |
| 4 | 4, 14, 21 | 1 Standard 1v1, 3 games of 2v2, 2 FFA, and 1 three-map async run. |

## Counting and rewards

- Keep the approved [24 daily templates](daily_quest_catalog_v1.md) unchanged.
  Assign three overlapping daily quests each day, and all four weeklies each week.
- A qualified completed game advances every matching objective once. Wins are
  unnecessary. Standard duels, 2v2, FFA and CTF retain distinct canonical modes.
- Async objectives count complete verified 3/5-map rolling async attempts, without
  waiting for cohort closure. Time Puzzles do not count as rolling async runs.
- Free Roll Tour needs two distinct three-map attempts overall, with at least one
  Free Roll Time Puzzle. The other can overlap an async requirement elsewhere.
  The alternative contest scopes are daily, weekly, monthly or seasonal; current
  publishing supports weekly/monthly/seasonal, so daily is a future option.
- The two Gauntlet attempts must be distinct and naturally finish. A verified
  terminal defeat counts, regardless of stars or stages cleared. Abandonment,
  incomplete map sets, practice and invalid results do not count. Live forfeits
  are excluded. Eligible activity must last at least 30 simulation seconds.
- Daily rewards: **2 Honey + 40 Nectar**. Weekly rewards: **8 Honey + 200 Nectar**.
  These amounts are approved provisional tuning for local testing.
- Claim all 21 daily rewards and all four weekly rewards before their resets for
  **10% extra quest Honey**, automatically with the final claim. The manifest
  includes the whole week, including days the player never opened the panel.
  Base weekly quest Honey is 74; the bonus is 7.40, totaling **81.40 Honey**.
  Quest Nectar totals **1,640**. Match rewards remain independent.
- A missed/expired daily prevents this bonus but does not remove ordinary rewards.
  No consecutive-login prize is implemented. Partial launch weeks are ineligible
  for the full-week bonus.

## Pacing

The standalone shared route is 36 live games, 9 async runs (33 maps), one three-map
Free Roll, and two Gauntlet attempts. At three minutes per live game/map and
15 minutes per Gauntlet, that is approximately **4 hours 6 minutes**.

The first curated daily bundle schedule adds roughly 63 minutes of weekly-specific
play after all dailies, for approximately **4 hours 33 minutes combined** under
those assumptions. Rotation includes all 24 daily templates over nine weeks.

These are planning estimates. The automated tests establish counts and reward
correctness; they do not measure human playtime, matchmaking waits or difficulty.
Real session timing and required-mode availability must be checked before any
rollout. Automatic substitutions for unavailable modes are not part of this v1.

See [implementation and local verification](quest_v1_implementation.md).
