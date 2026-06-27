# Honey Economy v0.1 Simulation Brief

Status: saved for future Honey economy sprint. Do not wire into production economy yet.

## Scope

Codify Honey Economy v0.1 for simulation only.

## Core Philosophy

- Honey rewards platform participation/contribution, not primarily winning.
- Wax/Command rewards winning and competitive performance.
- Honey should accrue slowly, mostly unnoticed match-to-match, then feel meaningful when whole Honey increases.
- Store Honey internally with fractional precision, but player-facing UI should display whole Honey only.
- Honey should feel "made one mouthful at a time."
- The best way to earn Honey should be naturally enjoying ENTaP, not artificial farming.

## Platform Contribution Rewards

- Buy $1 bundle: 0.25 Honey
- Buy $5 bundle: 1.00 Honey
- Buy $10 bundle: 2.00 Honey
- Buy $25 bundle: 4.00 Honey
- Buy $50 bundle: 9.00 Honey
- Buy $100 bundle: 20.00 Honey
- Purchase Warpath Premium: 2.00 Honey
- Purchase Warpath Elite: 4.00 Honey
- Download + launch second ENTaP title: 2.00 Honey
- Reach meaningful milestone in second ENTaP title: 2.00 Honey

## Referral Rewards

- Referral signup: 0.25 Honey
- Referral completes onboarding: 0.50 Honey
- Referral active 7 days: 1.00 Honey
- Referral active 30 days: 2.50 Honey
- Referral active 60 days: 4.00 Honey
- Referral rewards may escalate for repeated successful retained referrals; propose a safe escalation curve that does not allow abuse.

## Competitive Participation Rewards

- Complete free async match: 0.05 Honey
- Complete money async match: 0.10 Honey
- Complete free tournament match: 0.08 Honey
- Complete money tournament match: 0.15 Honey
- Complete free live match: 0.05 Honey
- Complete money live match: 0.10 Honey
- Complete all daily objectives: 0.25 Honey
- Complete weekly objectives: 1.00 Honey
- Complete all game modes this week: 1.00 Honey

## Competitive Success Recognition

Honey is not the primary reward for winning; Wax/Command is.

Contests may award Honey by rank, but the payout table must be flexible based on participant count and payout depth.

Default contest rank formula:

- Weekly contest: rank reward = 0.1 x rank_score
- Monthly contest: 2x weekly
- Seasonal contest: 4x weekly

Where rank_score should scale so the top paid place receives the max reward:

- Weekly max: 1.0 Honey
- Monthly max: 2.0 Honey
- Seasonal max: 4.0 Honey

Examples:

- If paying Top 10 weekly: 1st = 1.0, 2nd = 0.9, ... 10th = 0.1
- If paying Top 6 weekly: 1st = 1.0, 2nd = 0.8, 3rd = 0.6, 4th = 0.4, 5th = 0.2, 6th = 0.1 or propose smoother curve
- If paying Top 15 weekly: 1st = 1.0, 15th should still be small but nonzero; propose curve

Future simulator should return a formula/table generator that supports payout depth N.

## Championship Rewards

- Qualify for major championship: 5.00 Honey
- Championship winner bonus pool: +5 to +50 Honey depending on event tier and number of winners.
- Exact championship tiering TBD.

## Engagement Rewards

- Daily login: 0.10 Honey
- 7-day login streak bonus: 0.50 Honey
- 30-day login streak bonus: 2.00 Honey
- Community challenge completion: 0.50 Honey
- Featured community contribution: 1.00 Honey

## Hive Actions

- Joining a Hive: 0 Honey
- Hive actions do not directly earn Honey.
- Hive value comes from making Honey useful, not from paying players to join.

## Anti-Farming Rules

- Honey only awarded for completed matches.
- Early quits earn no Honey.
- Completion must meet minimum meaningful participation thresholds.
- Repeated matches against same opponent may receive diminishing Honey returns, but do not over-nerf legitimate repeated play.
- Because Honey is participation-weighted rather than win-weighted, there is less incentive to throw matches.
- Simulate abuse cases: instant quits, repeated same opponent, low-effort farming, multi-account farming.

## Simulation Request

Build a configurable economy simulator, not production wiring.

Simulate 90 days for:

1. Casual player
2. Average player
3. Competitive player
4. Hardcore player
5. Paying player
6. Referrer
7. Hive leader / organizer
8. Abuse/farmer profile

For each profile report:

- total Honey earned
- whole Honey visible to player over time
- source breakdown by category
- hours played
- matches completed
- purchases/referrals if applicable
- Honey/hour
- time to reach 10, 25, 50, 100 Honey
- whether any single action dominates
- whether farming beats normal play

Also simulate 14-member Hive purchasing power:

- mixed casual/average/competitive composition
- high-performing Hive
- paying-heavy Hive
- free-only Hive

Report:

- total Hive Honey after 30/60/90 days
- time to afford sample items priced at 25, 50, 100, 250 Honey
- proportional deduction examples for one purchase

Return:

- proposed JSON reward table
- simulation assumptions
- output tables
- recommended tuning changes
