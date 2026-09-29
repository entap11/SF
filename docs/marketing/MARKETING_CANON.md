# Swarmfront Marketing Canon

Status: Phase 0 draft; not approved for publication  
Owner needed: Swarmfront product owner  
Last audited: 2026-08-07

This file governs public claim language. It does not change gameplay rules, economy rules, release status, or product authority. Product specifications and authoritative implementation remain upstream. Any conflict fails closed: update the product or narrow the marketing claim before publication.

## Core positioning

**One-sentence Swarmfront pitch:** Swarmfront is a fast competitive strategy game about directing living swarms across a battlefield to feed, attack, capture, and outthink human or tactical bot opponents.

**ENTaP studio thesis:** The player is the customer, not a resource to be harvested.

**Campaign doctrine:** Make specific promises and show the receipts.

The pitch is a first-pass draft. The mechanics are supported by `SF-v1-LOCKED.md`; “fast” and the final audience phrasing require product/creative approval before publication.

## Claim-status system

| Status | Meaning | Public use |
| --- | --- | --- |
| `SHIPPED` | True in the currently available build and supported by cited proof. | May be drafted for publication, but still needs copy/asset approval. |
| `V1 COMMITMENT` | Approved launch requirement, not yet proven shipped. | Describe as a commitment, never as a current feature. |
| `FUTURE PRINCIPLE` | Studio doctrine or roadmap intent. | Describe as belief/intent, not current product behavior. |
| `VERIFY` | Repository evidence is incomplete, ambiguous, negative-only, or conflicting. | Do not publish. Named authority must resolve it first. |

`VERIFY` is a fail-closed exception to the three public statuses, not a fourth public label.

## Approved doctrine language

The following is the approved *candidate language* from the production plan. “Approved” here means wording is controlled for internal drafting; it does not override `VERIFY` status.

| Doctrine | Controlled public language | Current status |
| --- | --- | --- |
| Purchasable XP | **You cannot buy XP from us.** | `VERIFY` — XP is specified as match-earned, but absence of every purchase/grant path and the final economy policy are not yet certified. |
| Hidden adaptive difficulty | **The difficulty you choose is the difficulty you get. We do not secretly make the game easier because you lost or harder because you won.** | `VERIFY` — selected bot tiers/styles exist; a complete matchmaking, progressive-mode, remote-config, and telemetry audit is still required. |
| Tactical bot adaptation | **Bots should react to the strategy unfolding in the match. Tactical adaptation is part of a good opponent.** | `SHIPPED` for state-responsive decisions and distinct style weights; do not overstate learning or personalization. |
| Bot distinction | **Bots adapt to the battle, not to your retention profile.** | `VERIFY` — the battle-adaptation half is supported; the absence claim needs product-owner and code-owner certification. |
| Advertising truth | **The game in the ad is the game you play.** | `FUTURE PRINCIPLE` until every public asset passes gameplay-truth review. |
| Store currency | **One spendable currency is enough.** | `VERIFY` — Honey, Wax, Nectar, rank, and money-game concepts must be classified against the final V1 economy. |
| Conversion chains | **No currency alchemy. Progress, rank, and store value do not pass through conversion chains designed to make players lose track of what something costs.** | `VERIFY` — final economy and conversion graph are not certified. |
| Competition | **Competition is the core product, not a late-added side mode.** | `SHIPPED` as a product/gameplay description; availability of individual public modes must be stated separately. |
| Return path | **A returning player should reach ordinary play in approximately 1–3 intentional actions.** | `VERIFY` — requires a named ordinary-play route and physical-device action-count evidence. |
| Artificial friction | **We do not create artificial friction in order to sell its removal.** | `VERIFY` — studio/product policy needs approval and economy/UX review. |
| Cinematic license | **Our marketing may dramatize Swarmfront. It may never misrepresent the gameplay.** | `FUTURE PRINCIPLE`; enforce as a production gate. |

## Bot-language guardrails

Allowed:

- Bots react to authoritative battlefield state and player actions during the match.
- Bots may abandon bad tactics and express distinct strategic styles.
- A selected tier/style may produce a different opponent.

Prohibited until separately proven:

- “The bots never adapt.”
- “The AI learns you” or any claim of machine learning.
- “Difficulty never changes” without naming the mode and selection boundary.
- Any claim that loss-streak mercy, win-streak punishment, store-triggered difficulty, or retention-personalized difficulty is absent before the full decision-input audit is certified.

## Currency-language guardrails

- Call Honey spendable currency only after the V1 economy owner confirms its final role.
- Describe Wax, Nectar, XP, rank, stakes, and tracked balances by function; do not casually call all of them currencies.
- Do not claim “one currency” when the intended meaning is “one store/spend currency.”
- Do not claim “no pay-to-win” while `SF-v1-LOCKED.md` still permits minor, capped buff packs without an approved competitive-integrity interpretation.
- Publish a simple value-flow diagram before making the conversion-chain claim.

## Advertising-truth rules

- Cinematic framing, music, dramatic editing, and stylized cameras are allowed.
- Every mechanic implied by a spot must exist in the game or be unmistakably non-gameplay storytelling.
- Actual gameplay must be labeled and captured from a recorded Marketing Capture Candidate.
- Do not splice unrelated UI and gameplay into a false sequence.
- Do not show an input, mode, opponent behavior, reward, or outcome the player cannot obtain as presented.
- Every spot requires product-truth, visual-quality, rights, and final-render QA before publication.

## Public-copy rules

- Prefer observable, falsifiable claims.
- Attach each product claim to a source and a proof asset.
- State scope: current build, beta, V1 commitment, or future principle.
- Never convert `VERIFY`, `V1 COMMITMENT`, or `FUTURE PRINCIPLE` into present tense by shortening the copy.
- Marketing may simplify mechanics only when the simplified statement remains true for ordinary play.
- Do not announce the internal December 1, 2026 planning target.
- Do not use beta feedback without permission, faithful context, and appropriate de-identification.

## Prohibited claims

- “Bots never adapt.”
- “No pay-to-win” until the buff-pack and paid-mode conflict is resolved and defined.
- “Only one currency” without the store/spend qualifier.
- “No ads” or “ads never appear during matches”; the current policy permits reserved in-match banner areas.
- “All modes are live” or “public multiplayer is fully launched.”
- “December 1, 2026 launch.”
- “Player-first,” “fair,” or “built differently” as a substitute for a specific observable receipt.
- Any superlative, performance promise, player-count claim, testimonial, platform availability, or release date without current evidence.

## Principle register

Publication-ready means both claim truth and source assets are ready. Phase 0 does not grant publication approval.

| ID | Principle | Category | Public shorthand | Claim status | Product proof/source | Proof asset needed | Publication-ready? | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SF-MKT-001 | XP is earned through play and is not purchasable. | Progression / Money | You cannot buy XP from us. | `VERIFY` | `SF-v1-LOCKED.md` §7.1 says XP is earned per match; purchase-path search found no explicit XP SKU, but negative search is not certification. | Economy-owner sign-off plus automated SKU/grant-path audit. | No | Authority: product + economy owner. |
| SF-MKT-002 | Bot difficulty is not secretly raised after wins or lowered after losses. | Competition / Bots | The difficulty you choose is the difficulty you get. | `VERIFY` | `scripts/state/progressive_config.gd`, `scripts/ops/ops_state.gd`, and selected tier/style routes. | Decision-input audit covering matchmaking, progression, remote config, telemetry, and experiments. | No | Authority: product + bot-system owner. |
| SF-MKT-003 | Bots may react tactically to live battlefield state. | Competition / Bots | Bots adapt to the battle. | `SHIPPED` | `docs/current_project_status.md` §Bot Depth; `scripts/ops/ops_state.gd` style profiles and live decisions. | Gameplay clip with fixed build/fixture provenance. | No | Say “react/adapt tactically,” not “learn.” |
| SF-MKT-004 | Bot behavior is not personalized from a retention profile. | Competition / Bots | Not to your retention profile. | `VERIFY` | `docs/work_codex_handoff_2026-03-11.md` says not to tune specifically to one player; future modeled-player work is documented separately. | Full data-flow audit and product-owner certification. | No | Absence claim cannot be proven from selected files alone. |
| SF-MKT-005 | Bot styles should produce meaningfully different decisions. | Competition / Bots | Opponents with a point of view. | `SHIPPED` | `docs/current_project_status.md` lines 39–52; five styles and three tiers exist. | Side-by-side behavior capture; tuning caveat. | No | Current doc says some styles remain too similar. |
| SF-MKT-006 | Marketing may dramatize but may not depict a different game. | Honesty / Ads | The game in the ad is the game you play. | `FUTURE PRINCIPLE` | Marketing production plan §§7, 15–16. | Spot-to-gameplay truth checklist and approved final spot. | No | Governance claim, not yet a shipped asset claim. |
| SF-MKT-007 | Actual gameplay footage must retain build and capture provenance. | Honesty / Development | Show the receipts. | `V1 COMMITMENT` | Marketing production plan §16. | Marketing Capture Candidate record and raw-footage manifest. | No | Capture candidate does not yet exist. |
| SF-MKT-008 | There is one clear store/spend currency. | Money | One spendable currency is enough. | `VERIFY` | `docs/economy/honey_v2_wiring.md`; Honey implementation; other tracked systems include Wax and Nectar. | Approved economy taxonomy and player-facing screenshots. | No | Authority: economy owner. |
| SF-MKT-009 | Progress, rank, and store value do not use obscuring conversion chains. | Money / Honesty | No currency alchemy. | `VERIFY` | Marketing production plan §6; multiple economy drafts are present. | Final V1 value-flow diagram and code/config audit. | No | Final economy not certified. |
| SF-MKT-010 | Competitive advantage is not sold. | Competition / Money | Skill is not for sale. | `VERIFY` | Conflict: `SF-v1-LOCKED.md` §9 permits minor, capped buff packs; buff purchasing/activation systems exist. | Explicit competitive-integrity policy plus mode-by-mode entitlement audit. | No | Must resolve conflict before “no pay-to-win.” |
| SF-MKT-011 | Competition is the core gameplay product. | Competition | Competition is the point. | `SHIPPED` | `SF-v1-LOCKED.md` core loop; `docs/player_config_matrix.md`; PvP and async contracts. | Current gameplay montage and mode-availability copy. | No | Do not imply every mode is public/live. |
| SF-MKT-012 | Returning players should reach ordinary play in about 1–3 intentional actions. | Time / UX | Back to play in 1–3 actions. | `VERIFY` | `SF-v1-LOCKED.md` §6 targets clear Play entry; menu implementation exists. | Named route, cold/warm-state test, device recordings. | No | “Ordinary play” needs a precise definition. |
| SF-MKT-013 | ENTaP does not manufacture friction in order to sell its removal. | Time / Money | We do not sell relief from problems we made. | `VERIFY` | Marketing production plan §§2–3; no binding product policy found. | Product-owner policy approval and UX/economy friction audit. | No | Studio doctrine requires authority. |
| SF-MKT-014 | The player is the customer, not a resource to be harvested. | Studio | The player is the customer. | `FUTURE PRINCIPLE` | Marketing production plan §2. | Studio-owner approval plus a linked set of observable receipts. | No | Publish as thesis, not proof by itself. |
| SF-MKT-015 | Claims should be observable and falsifiable. | Honesty | Could a player catch us? | `FUTURE PRINCIPLE` | Marketing production plan §3. | Claim ledger linked to sources and versioned proof. | No | Internal campaign rule. |
| SF-MKT-016 | Marketing states whether a claim is shipped, committed, future, or unresolved. | Honesty | Say what is true now. | `FUTURE PRINCIPLE` | Marketing production plan §4; this canon. | Publication checklist enforcing status. | No | Never expose `VERIFY` as finished copy. |
| SF-MKT-017 | Ads do not require interaction before menu or match flow continues. | Time / Ads | No ad holds the game hostage. | `SHIPPED` | `docs/advertising_policy.md` line 26 and `scripts/state/ad_manager.gd`. | Device capture of all approved placements and zero-fill behavior. | No | Policy permits timed pre/post-match ads and HUD banners. |
| SF-MKT-018 | Ads must not pause play, cover controls, or obscure critical information. | UX / Ads | Gameplay stays readable. | `SHIPPED` | `docs/advertising_policy.md` lines 28–36; reserved surfaces. | Representative-device overlay QA. | No | Needs current visual evidence. |
| SF-MKT-019 | Personalized ads remain off until compliant consent/privacy exists. | Privacy / Ads | No personalized ads by default. | `SHIPPED` | `docs/advertising_policy.md` line 33 and ops defaults. | Config snapshot and privacy/legal approval. | No | Public wording requires counsel/product approval. |
| SF-MKT-020 | Players with the zero-ads entitlement are not shown ads. | Money / Ads | Zero ads means zero ads. | `SHIPPED` | `docs/advertising_policy.md` line 30; AdManager entitlement path. | Entitlement matrix and device capture. | No | Internal ticker is not an ad impression. |
| SF-MKT-021 | Player-facing ads open external destinations only after intentional input. | Safety / Ads | No surprise exits. | `SHIPPED` | `docs/advertising_policy.md` line 31. | Tap/no-tap behavior QA. | No | Test all provider adapters before publication. |
| SF-MKT-022 | Core controls use a compact, consistent command vocabulary. | UX / Gameplay | Direct the swarm. | `SHIPPED` | `SF-v1-LOCKED.md` §§4–5; `docs/tutorial_controls_v1_spec.md`. | Clean tutorial/gameplay capture. | No | Avoid promising a particular gesture until current tutorial work is merged. |
| SF-MKT-023 | Art and presentation do not determine or mutate mechanics. | Development / Honesty | The sim knows. | `SHIPPED` | `AGENTS.md`; `SF-v1-LOCKED.md` line 267; authoritative simulation contracts. | Architecture receipt suitable for a development Dispatch. | No | Explain in player language. |
| SF-MKT-024 | Match rules are resolved by authoritative simulation, not visual inference. | Competition / Development | Results come from the game state. | `SHIPPED` | `AGENTS.md`; `OSF/_canonical/Swarmfront_Canon_v1.md`; PvP authority docs. | Determinism/replay demonstration. | No | Scope multiplayer claims carefully by current gate status. |
| SF-MKT-025 | Enemy lanes and structures cannot be directly commandeered through input. | Gameplay | Command your swarm, not theirs. | `SHIPPED` | `SF-v1-LOCKED.md` §§1.2, 4. | Input/gameplay clip. | No | Mechanic-specific candidate principle. |
| SF-MKT-026 | Tower chains require complete team control to activate. | Gameplay / Competition | Own the chain. Earn the power. | `SHIPPED` | `SF-v1-LOCKED.md` §1.3. | Clear before/after gameplay capture. | No | Confirm current maps expose representative chain play. |
| SF-MKT-027 | Beta criticism is represented faithfully, not rewritten into praise. | Honesty / Community | Show what testers actually told us. | `FUTURE PRINCIPLE` | Marketing production plan §§10, 22. | Consent/de-identification record and source-preserving editorial review. | No | No beta quote is authorized by this canon. |
| SF-MKT-028 | Listening means diagnosing the experience, not blindly implementing every proposed fix. | Community / Development | Hear the problem beneath the request. | `FUTURE PRINCIPLE` | Marketing production plan §10. | One approved FROM THE BETA case with before/after evidence. | No | Candidate stalemate/speed story still requires actual source feedback. |
| SF-MKT-029 | Analytics failure must not block or alter the player experience. | Privacy / Development | Measurement is not gameplay. | `V1 COMMITMENT` | `docs/ui/NEW_TITLE_UX_ADOPTION_GUIDE.md` adoption gate; analytics isolation harnesses. | Release-mode failure test and data inventory. | No | Confirm all production paths before elevating. |
| SF-MKT-030 | Release evidence must fail closed rather than turn uncertainty into a claim. | Honesty / Development | Unknown is not passed. | `FUTURE PRINCIPLE` | Performance/release-readiness governance and marketing plan §23. | Public-facing explanation with a concrete release gate. | No | Avoid implying flawless software. |
| SF-MKT-031 | Free play is supported without making ad revenue outrank player experience. | Money / Ads | Player experience before ad revenue. | `V1 COMMITMENT` | `docs/advertising_policy.md` lines 3 and 36; free modes in configuration/contracts. | Monetization-owner sign-off and complete free-path QA. | No | Do not imply every feature is free. |
| SF-MKT-032 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-033 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-034 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-035 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-036 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-037 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-038 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-039 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-040 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-041 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-042 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-043 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-044 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-045 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-046 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-047 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-048 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-049 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |
| SF-MKT-050 | TBD | TBD | TBD | `VERIFY` | Source principle not located. | Locate existing manifesto/blogette bank. | No | Placeholder preserved; do not invent. |

## Phase 0 status

- 31 source-grounded principle candidates are registered.
- 19 placeholders remain intentionally blank because the referenced 12–15 essay bank was not found.
- No principle is publication-approved at this checkpoint.
- Gate M0 remains open until the product owner approves the pitch/status model and resolves the claims listed in the checkpoint report.
