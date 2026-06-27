# Hive Governance Rules

Status: working product rules for Swarmfront Hive governance. These rules describe current code behavior plus the near-term legal/product intent needed before public Hive spending and deeper platform migration.

Source of truth in code today: `scripts/state/hive_clan_state.gd`.

## Governance Goals

Hives should feel persistent, player-led, and hard to hijack.

The governance model should protect ordinary members from unilateral leadership punishment, protect Hives from abandoned leaders, and keep important changes auditable. Hives are intended to become platform-level communities later, so rules should avoid relying on display names or Swarmfront-only assumptions wherever possible.

## Hive Size And Roles

A Hive can have up to 14 members.

Each Hive has three role levels:

- Queen
- Soldier
- Member

Each Hive can have only one Queen.

Each Hive can have up to three Soldiers.

Every player in a Hive has one role. A player can belong to only one Hive at a time.

## Queen Powers

The Queen is the primary Hive leader.

The Queen can:

- invite players to the Hive
- approve or decline applications
- promote a Member directly to Soldier, up to the three-Soldier cap
- remove ordinary Members directly
- edit the Hive profile/about text
- set or clear the pinned notice
- enter Hive tournaments or Hive-cost events where the current code allows Hive Honey spending

The Queen cannot:

- remove themself directly
- directly remove a Soldier
- directly remove another Queen
- directly demote a Soldier without the demotion vote path
- bypass Call Sign/community standards
- bypass future platform identity, payment, or Honey rules

## Soldier Powers

Soldiers are trusted officers.

Soldiers can:

- invite players to the Hive
- approve or decline applications
- set or clear the pinned notice
- participate in Soldier demotion votes
- vote to remove the Queen
- participate in broader leadership removal votes
- participate in Soldier promotion votes
- enter Hive tournaments or Hive-cost events where the current code allows Hive Honey spending

Soldiers cannot:

- directly remove Members
- directly promote Members
- directly demote other Soldiers
- directly remove the Queen
- edit the Hive profile/about text
- bypass the Queen on rules that explicitly require Queen authority

## Member Powers

Members are the normal Hive population.

Members can:

- apply to join Hives
- accept or decline Hive invites
- request to leave their Hive
- cancel a pending leave request
- apply to become a Soldier
- vote in broad leadership removal votes when eligible
- participate in Hive activity and tournament roster flows when selected

Members cannot:

- invite players
- approve applications
- remove other members
- directly promote or demote leaders
- spend Hive Honey or enter Hive-cost events under the current code

## Invites And Applications

Queens and Soldiers can invite players.

Invites expire after 48 hours.

Invites always resolve to Member role. Even if a caller requests a higher role, the invite is sanitized back to Member.

A Hive cannot exceed 14 members, counting current members and pending invites.

A player already in a Hive cannot accept another Hive invite or application without leaving their current Hive first.

Open invites/applications for other Hives are closed when a player joins a Hive.

## Hive Creation

A player can create a Hive only if they are not already in a Hive.

The creator becomes Queen.

Current code limits Hive creation to one Hive per player per seven-day window.

## Direct Member Removal

The Queen can directly remove an ordinary Member.

Direct removal:

- cannot target the Queen
- cannot target a Soldier
- cannot target the acting Queen
- applies a seven-day cooldown before the removed player can rejoin the same Hive
- clears that player's pending governance votes and governance state

Current code retires a Hive if the last member is removed or leaves.

## Soldier Promotion

There are two Soldier promotion paths.

Direct promotion:

- Queen only
- target must be a Member
- cannot target the Queen themself
- cannot exceed three Soldiers

Promotion vote:

- any active Hive member except the target can vote
- target must be a Member
- cannot exceed three Soldiers
- eligible voters are active non-target Hive members
- active means seen within the voter activity window
- the vote passes with a simple majority of eligible voters

Members can also apply for Soldier. This creates or marks a promotion vote record for that member.

## Soldier Demotion

Soldiers cannot be demoted by direct Queen action.

A Soldier demotion requires:

- a Queen vote
- at least one supporting Soldier vote
- target must be a Soldier
- target cannot vote to demote themself
- only Queen or Soldiers can cast Soldier demotion votes

When the requirement is met, the Soldier returns to Member.

## Queen Removal

Queen removal has a dedicated Soldier vote path.

Only Soldiers can vote to remove the Queen.

The current rule requires three valid Soldier votes, matching the maximum Soldier count.

When Queen removal passes:

- the Queen becomes a Member
- the senior Soldier becomes the new Queen
- seniority is based on earliest join time
- if join time ties, higher Honey contribution breaks the tie
- Queen-removal votes and Soldier-demotion votes are cleared

If no senior Soldier can be found, current code falls back to the actor who completed the vote.

## Broad Leadership Removal

The broader leadership removal vote exists as a high-consensus safety valve.

Any Hive member can vote to remove a Queen or Soldier from leadership through this path.

Rules:

- target must be Queen or Soldier
- actor must be a Hive member
- actor cannot target themself
- target becomes Member if removal passes
- if the target was Queen, the Hive must still end with a Queen

Current threshold:

- at least nine eligible non-target voters are required before this vote can be used
- every eligible active non-target voter must vote yes

This makes broad leadership removal intentionally hard. It is designed for serious Hive consensus, not ordinary disputes.

## Vote Windows And Inactive Voters

Governance votes expire after 48 hours.

Inactive voters are stripped from active governance votes.

Current active-voter window:

- a player is an active voter if their `last_seen_at_unix` or join time is within the last seven days

This inactive-voter rule currently affects vote eligibility and vote cleanup. It does not yet perform automatic leader succession.

## Leaving A Hive

Leaving is delayed.

Rules:

- a player requests to leave
- the leave becomes effective after 24 hours
- the player can cancel the leave before it finalizes
- final leave removes the player from membership
- final leave clears that player's governance state
- the player cannot rejoin the same Hive for seven days

If the leaving player was Queen and the Hive still has members, current code ensures a new Queen exists.

Current replacement order when a Hive has no Queen:

- promote the first Soldier by sorted player ID
- if no Soldier exists, promote the member with the highest Honey contribution

This differs from the Queen-removal senior-Soldier rule and should be reconciled during the inactive-succession sprint.

## Hive Retirement And Archives

If a Hive becomes empty, current code retires the Hive.

Retirement:

- moves Hive award records to the company trophy case
- marks those awards as company-owned archive records
- removes the Hive from active Hive state

Product/legal intent:

- historical Hive achievements should be preserved wherever possible
- defunct Hive history should not disappear from championship or trophy history
- future ENTaP migration should archive rather than silently erase meaningful Hive identity/history

## Hive Comms And Profile

Hive communication is intentionally limited.

Current supported surfaces:

- pinned notice
- Hive profile/about text
- limited Hive feed/event entries

Pinned notices:

- Queen or Soldier can update
- max length is 220 characters

Hive profile/about:

- Queen only
- max length is 300 characters
- has a 24-hour update cooldown

Future public chat, direct messages, and broader social features should not expand until reporting, moderation, blocking, and support workflows are ready.

## Hive Honey And Spending

Current code has a provisional Hive Honey strength model based on member Honey contribution minus Hive Honey spent.

Current spending authority:

- Queen or Soldier can spend Hive Honey under code paths that check `can_spend_hive_honey`

Important: this does not match the latest Honey economy intent.

Legal/product intent for future Honey sprint:

- Honey belongs to players, not a Hive treasury
- Hive purchasing power should be derived from current members' player-owned balances
- Hive purchases should show a proportional deduction preview before final confirmation
- purchases should debit members proportionally only after approval
- no public Hive spending should ship until this mismatch is fixed

Until the Honey sprint, Hive Honey rules in UI/docs should be treated as provisional simulation/test behavior.

## Inactive Queen Succession

Current code implements this as a member-initiated claim path.

Legal/product intent:

- if a Hive Queen is inactive for roughly 12 weeks, the Hive should be able to continue without being trapped by abandonment
- succession should be deterministic, auditable, and conservative
- historical recognition remains with the former Queen, but operational leadership moves to an active eligible member

Planned rule:

- Queen is considered inactive for succession after 12 weeks without valid activity
- if active Soldiers exist, promote the senior active Soldier
- seniority should prefer earliest joined Soldier, with Honey contribution as a tie-breaker
- if no active Soldier exists, promote the active Member with the strongest durable contribution record
- if no active member exists, do not silently transfer leadership
- emit a Hive event recording old Queen, new Queen, reason, and inactivity window
- clear governance votes involving the old/new Queen as needed

Open implementation decision:

- whether inactivity succession should happen automatically during runtime refresh, require a member-initiated claim, or require a vote/confirmation prompt

Implemented first version:

- `intent_claim_inactive_queen_succession(hive_id, actor_player_id)`
- claim is allowed only when Queen inactivity exceeds 12 weeks
- claimant must be an active non-Queen Hive member
- successor is chosen deterministically from active Soldiers first, then active Members
- smoke coverage exists in `tools/hive_inactive_queen_succession_smoke_test.gd`

## Rules That Should Not Change Without Review

These rules are high-trust governance rules and should not be changed casually:

- ordinary Members cannot be directly removed by Soldiers
- Soldiers cannot be directly removed by Queen action
- Queen removal requires Soldier consensus
- broad leadership removal requires high active-member consensus
- display names are never identity authority
- Honey economy/spending rules stay provisional until the Honey sprint
- communication expansion requires moderation/reporting support first

## Implementation Checklist

Near-term sprint tasks:

- add inactive Queen succession
- reconcile succession ordering across Queen removal, Queen leave, and inactive succession
- add public-facing rule text in UI where Hive governance actions are shown
- add event/audit output for every serious governance action
- keep Hive Honey spending gated or clearly marked provisional until the Honey model is corrected

Future platform-readiness tasks:

- add optional ENTaP Hive ID fields
- add optional ENTaP account ID fields to member records
- add export/import snapshots for Hive migration
- make archived Hive history durable across platform migration
- move canonical Hive identity/membership to ENTaP when the platform is ready
