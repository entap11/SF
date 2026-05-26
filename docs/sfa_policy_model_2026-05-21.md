# SFA Policy Model

Date: May 21, 2026

## Product Rule

Swarmfront Academy is a school-hive program. SFA eligibility requires a current high-school enrollment attestation. The player is responsible for attesting that they are enrolled at the selected school for the selected school year.

## Eligibility Window

SFA eligibility is capped at four school years from the declared freshman school year.

Example:
- Freshman school year: `2026-2027`
- Eligible SFA school years: `2026-2027`, `2027-2028`, `2028-2029`, `2029-2030`
- A `2030-2031` high-school attestation is rejected for SFA eligibility.

Repeating high school does not extend SFA eligibility by default. Rare exceptions can be handled later by manual policy, but the product default is to move the player into SFU or the open game.

## Money And Comms

SFA restrictions follow the player globally:
- no DMs
- no private chat
- no voice
- no SFA tournament buffs
- no SFA cash awards
- no SFA progression from adult money games

Cash-entry, cash-prize, and withdrawable-value competitive paths are adult-only and must also pass jurisdiction checks before launch.

## School Hive Review

School data starts as self-reported. A school hive becomes reviewed only after an explicit review action.

Review checks should confirm:
- the school name is correct enough to expose publicly
- the review school year is current
- roster members have attested enrollment for that school year
- no material enrollment dispute is open

Public school name should stay as `Pending School` until the hive is approved.

## Hive Bonus

The review bonus belongs to the school hive, not individual players.

A hive earns the bonus only when:
- the school hive review status is approved
- every rostered player has attested enrollment for the review school year
- no material dispute is open

If a dispute opens, future hive bonus eligibility pauses until review is resolved.

## SFA Analytics Grant

Every active SFA student receives the Tier 1 analytics package entitlement: `analytics_pack_tier_1`.

This is an individual student entitlement, not a school-data-entry bounty. It is intended to make SFA more attractive, introduce students to analytics packages, and improve retention without creating a cash or competitive advantage path.

The grant is idempotent. Re-attesting or rejoining SFA should not duplicate the package credit.

## Self-Policing

SFA is designed to be low-touch at launch:
- players self-attest enrollment
- school hives police membership
- officers can remove ineligible players through existing team controls
- formal enrollment complaints can pause hive bonus eligibility
- no document upload or personal-data-heavy verification is required by default

Attorney review is still required before public launch, especially around minors, privacy copy, school affiliation, and paid competition boundaries.

## SFU Difference

Swarmfront University is an adult community and tournament layer, not a restricted account type.

SFU players are expected to be 18+:
- normal DMs/chat/voice are allowed
- normal money games are allowed, subject to cash-game age and jurisdiction checks
- normal buffs and account functionality are allowed
- college, university, trade-school, or post-secondary affiliation affects SFU community/tournament eligibility, not global gameplay access

SFU tournament configuration controls the event rules:
- `buffs_allowed`
- `cash_prizes_allowed`
- `entry_fee_allowed`
- `program_roster_required`
- `official_sfu_event`

Default official SFU tournament posture should be no-buff. Selected SFU open/special events can allow buffs and cash prizes when the player and jurisdiction are eligible.

SFA players can transition to SFU only after they are adult-eligible. If they do not join a post-secondary program, they move into the open adult game instead.

## Backend Ownership

Scholastic state is owned by `tools/scholastic-service`.

The service owns:
- SFA/SFU profiles
- school hives and college/trade programs
- enrollment attestations
- school hive review status
- enrollment complaints and disputes
- SFA/SFU tournament definitions
- scholastic tournament result eligibility
- scholastic activity metrics for DAU/WAU/MAU, new players, and time-in-app comparison
- SFA advertising policy resolution
- audit events

The game client can cache and display this state, but persistent SFA/SFU eligibility and hive bonus decisions should come from the backend.

## SFA Metrics

The admin surface should track:
- total schools in SFA
- approved schools
- disputed schools
- hive-bonus-eligible schools
- total known players
- active SFA players
- active SFU players
- average teams per school
- median teams per school
- DAU, WAU, and MAU by SFA/SFU/open ecosystem
- new players by day, week, and month
- average time in app for SFA compared with open-game population

## SFA Advertising

SFA players should only receive family-safe advertising.

Default SFA ad policy:
- family-safe inventory only
- no behavioral targeting
- no personalized ads
- no targeting from school/classroom/scholastic data
- child-directed treatment flag enabled when passed to ad SDKs
- maximum ad content rating should be the safest available setting

This is a conservative product default pending attorney and ad-network review.
