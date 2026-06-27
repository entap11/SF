# Nectar / Battle Pass First-Pass Economy Frame

Status: first slice implemented in BattlePassConfig/BattlePassState with centralized base rewards, Premium/Elite multipliers, Crucible suppression, idempotency, and first-win-of-day bonus.

## Core Philosophy

- Honey rewards participation.
- Wax rewards pure competitive success.
- Nectar rewards both participation and winning.
- Nectar is Battle Pass XP.
- Crucible should award 0 Nectar.

## Pass Multipliers

- Classic: 1.00x
- Premium: 1.30x
- Elite: 1.60x

## Target Completion Pacing

- Classic players should need roughly 100-120 hours of valid gameplay to complete the standard pass.
- Premium should land around 77-92 hours due to 1.3x multiplier.
- Elite should land around 63-75 hours due to 1.6x multiplier.
- Tune after telemetry.

## Reward Rules

- Every valid match earns a participation reward.
- Winning earns an additional win bonus.
- Paid/money games may earn slightly more Nectar than free games, but only modestly.
- Do not make money games the dominant Nectar farm.
- All reward values must live in centralized config, not scattered magic numbers.

## Mode Group

Standard Competitive PvP includes:

- Standard PvP
- CTF
- HCTF

## Base Nectar Table Before Pass Multiplier

Standard Competitive PvP - Free Play:

- Complete valid match: 10 Nectar
- Win bonus: +8 Nectar
- Total win: 18 Nectar

Standard Competitive PvP - Money Match:

- Complete valid match: 12 Nectar
- Win bonus: +10 Nectar
- Total win: 22 Nectar

Progressive - Free:

- Complete valid match: 10 Nectar
- Win bonus: +8 Nectar
- Total win: 18 Nectar

Progressive - Money:

- Complete valid match: 12 Nectar
- Win bonus: +10 Nectar
- Total win: 22 Nectar

Async - Free:

- Complete valid match: 8 Nectar
- Win bonus: +6 Nectar
- Total win: 14 Nectar

Async - Money:

- Complete valid match: 10 Nectar
- Win bonus: +8 Nectar
- Total win: 18 Nectar

Tournament:

- Complete tournament match: 12 Nectar
- Tournament match win bonus: +10 Nectar
- Tournament champion bonus: +75 Nectar
- Keep launch placement bonuses simple; only champion bonus for now unless current tournament code already exposes placement safely.

## First Win Of Day

- First competitive win: +20 Nectar
- Should apply once per day across eligible competitive modes, not once per mode.

## Daily Challenges

- Easy: 40 Nectar
- Medium: 75 Nectar
- Hard: 120 Nectar

## Weekly Challenges

Only use simple counters for Season 1. Do not build granular in-match telemetry yet.

- Play Standard Competitive PvP, including CTF/HCTF: goal 25, reward 300
- Win Standard Competitive PvP: goal 10, reward 300
- Play Async Matches: goal 20, reward 250
- Win Async Matches: goal 8, reward 250
- Play Tournament Matches: goal 8, reward 300
- Win Tournament Matches: goal 3, reward 350
- Play Progressive Matches: goal 15, reward 250
- Win Progressive Matches: goal 6, reward 300
- Play Money Matches: goal 10, reward 350
- Win Money Matches: goal 4, reward 350
- Complete all weekly challenges: bonus +750

## Premium / Elite Behavior

- Same base reward table for everyone.
- Apply multiplier after calculating base Nectar.
- Classic = 1.0x
- Premium = 1.3x
- Elite = 1.6x
- Use deterministic rounding; define whether to floor, round, or accumulate fractional remainder.
- Preferred: fixed-point internal accounting or fractional carry so Premium/Elite do not lose value to rounding.

Examples:

- Standard free win base 18:
  - Classic earns 18
  - Premium earns about 23/24 depending rounding
  - Elite earns about 29
- Money match win base 22:
  - Classic earns 22
  - Premium earns about 29
  - Elite earns about 35
- 300 Nectar weekly:
  - Classic earns 300
  - Premium earns 390
  - Elite earns 480

## Secret / Post-100 Progression

- After completing standard Battle Pass, Premium holders unlock Premium Ascension.
- Elite holders unlock Elite Ascension.
- Ascension rewards should be prestige/cosmetic only.
- No gameplay advantage.
- Thresholds should be tuneable and not necessarily shown explicitly.
- Design target:
  - Only the most active 20-30% of Premium holders reach meaningful Premium Ascension.
  - Only the most active 20-30% of Elite holders meaningfully progress through Elite Ascension.
- Do not hard-code this as a permanent ratio; tune by season telemetry.

## Anti-Harvest Rules

A match must be valid before it can award Nectar.

No Nectar for:

- Crucible
- Tutorial
- Practice
- Custom/private matches
- No contest
- Refunded match
- Duplicate match reward event
- Match below minimum duration
- Immediate surrender
- AFK / insufficient input
- Insufficient match participation
- Invalid/desynced result

Diminishing/limits:

- Repeated same opponent in a rolling window should diminish Nectar.
- Excessive daily farming should trigger soft diminishing returns, not a hard stop.
- Async should have extra caution/caps because many games can run simultaneously.
- Money match Nectar bonus should remain modest.

## Implementation Requirements

1. Centralize Nectar config:
   - reward amounts
   - pass multipliers
   - eligible modes
   - anti-harvest thresholds
   - daily/weekly challenge definitions
   - first-win-of-day bonus
   - diminishing return settings
2. Add a NectarRewardPolicy helper:
   - classify match type
   - determine free vs money
   - verify eligibility
   - apply anti-harvest gates
   - calculate base participation reward
   - calculate win bonus
   - calculate challenge rewards
   - apply pass multiplier
   - emit breakdown
3. Add reward breakdown object:
   - match_id
   - player_id
   - mode_group
   - is_money_match
   - pass_tier
   - participation_nectar
   - win_bonus_nectar
   - first_win_bonus_nectar
   - daily_challenge_nectar
   - weekly_challenge_nectar
   - multiplier
   - final_nectar
   - validity_status
   - anti_harvest_reason_if_blocked
4. Add idempotency:
   - Nectar rewards should apply once per match_id/player_id/reward_type.
   - Duplicate result events must not double-award.
5. Add tests:
   - Standard free win/loss rewards.
   - Money win/loss rewards.
   - Async win/loss rewards.
   - Tournament win/champion rewards.
   - Premium and Elite multipliers.
   - Crucible awards 0 Nectar.
   - Tutorial/practice/custom awards 0.
   - No contest/refund awards 0.
   - Duplicate match result does not double-award.
   - First win of day only applies once.
   - Weekly counters increment for simple match played/won cases.
   - CTF/HCTF count under Standard Competitive PvP.
6. Add telemetry:
   - nectar_award_attempt
   - nectar_awarded
   - nectar_blocked_antiharvest
   - nectar_blocked_crucible
   - nectar_first_win_awarded
   - nectar_daily_challenge_progress
   - nectar_weekly_challenge_progress
   - nectar_weekly_challenge_completed
   - nectar_multiplier_applied
   - nectar_duplicate_award_ignored

## Questions Before Implementation

1. Where is the current Battle Pass / Nectar award path?
2. Where should pass tier be read from?
3. Do we already distinguish free vs money matches in match metadata?
4. Do CTF and HCTF currently map through vs_mode, mode rules, or tournament metadata?
5. What minimum match duration/input data already exists for anti-harvest?
6. Where should daily/weekly challenge state persist?
7. Does Nectar currently store integers only, or can we use fixed-point/fractional carry?
8. What is the safest first slice?

## Recommended First Slice

- Centralized config.
- NectarRewardPolicy calculator.
- Tests for base match rewards and multipliers.
- Crucible/no-reward guard.
- Idempotency guard.
- Simple weekly counter scaffolding for match played/won.
- Do not build granular in-match challenge telemetry yet.
