# Honey, Wax, and Nectar Current-to-Target Writer Matrix

Status: Implemented in certification; capability canaries remain gated off
Inventory date: 2026-08-17
Repository/branch: `project` / `codex/iphone-startup-hitch-diagnosis`

## How to read this inventory

This inventory classifies every located production-capable mutation family,
including dormant legacy paths that can become writers if instantiated. Test
fixtures and smoke harnesses are not production writers; they are listed under
the code they exercise when they affect migration coverage.

The only allowed classifications are:

- **RETAIN**: remains the one target writer or remains non-economic lifecycle/
  infrastructure with its current responsibility.
- **CONVERT TO INTENT OR PROJECTION**: keeps an API/UI role but loses authority
  to calculate or persist economic value.
- **SUPPRESS**: unavailable in production; may remain in isolated tests or
  migration tooling.
- **DELETE**: redundant legacy economic path with no target runtime role.

The discovery inventory below is retained as the migration record. Runtime
implementation followed under separate authorization; unrelated worktree
changes were excluded from the backend commits.

## Current stores and authority overlaps

| Concept/store | Persistence now | Current role | Target |
| --- | --- | --- | --- |
| `ProfileManager._honey_balance` | Client `user://profile.cfg` | Honey wallet and store debit | Read-only Platform snapshot; no economic persistence authority |
| `HoneyProgressionState` reward/dedupe state | Client `user://honey_progression_state.json` | Calculates rewards, submits amounts, and falls back to local wallet mutation | Presentation/pending-intent state only |
| `HiveClanState` Honey snapshots | Client `user://hive_clan_state.json` | Member balance snapshots and proportional debit | Hive display projection and purchase intent only |
| VS `HoneyLedger` | Memory or JSON file; configured default is `file` | Remote Honey balance, activity rewards, direct grants/debits, Hive debit | Replaced by Platform PostgreSQL Honey ledger |
| `BattlePassState` | Client `user://battle_pass_state.json` | Nectar, fractional carry, level, challenges, claims, entitlement state | Seasonal progression projection and claim intents |
| Legacy `SwarmPassState` | Client `user://swarm_pass_state.json` | Separate Nectar wallet/progression | Delete |
| Legacy `EconomyBuffState` | Client `user://economy_buff_state.json` | Separate Nectar awards/wallet-related state | Delete Nectar writer; migrate any still-needed non-economy buff state separately |
| `RankStore.rank_players.wax_score` | PostgreSQL | Standard Wax and derived Rank fields | Platform canonical Wax writer plus Rank projection; refactor journal semantics |
| `RankState` | Client `user://rank_state.json` | Remote cache plus enabled local fallback writer | Read projection and intent transport only |
| `CrucibleState` | Client `user://crucible_state.json` | Remote mirror plus enabled local escrow/settlement/balance writer | Lifecycle/display projection and intent transport only |
| Legacy VS `CrucibleLedger` | Memory or JSON file; configured default is `file` | Complete alternate Wax balance/escrow/settlement ledger | Delete after migration; suppress immediately in production |
| VS `vs_crucible_*` tables | PostgreSQL | Durable alternate Wax accounts, escrow, settlement, reserve, reversals | Migrate custody to Platform; VS retains lifecycle/reference receipts only |

There is currently no server Nectar/progression store. That is missing target
infrastructure, not a vendor dependency.

## Honey writers

| Current path/capability | Current mutation | Classification | Exact target treatment |
| --- | --- | --- | --- |
| `scripts/profile/profile_manager.gd`: `set_honey_balance`, `add_honey`, `spend_honey` | Directly changes and saves the client Honey wallet | **CONVERT TO INTENT OR PROJECTION** | Keep snapshot getter/signal for UI. Replace setters with application of authenticated Platform snapshots; store purchase emits a product/action intent and waits for a committed receipt. No optimistic authoritative balance. |
| `scripts/state/honey_progression_state.gd`: `intent_grant_player_honey` and activity reward methods | Calculates/accepts reward amount, tracks client dedupe, then writes locally or calls VS | **CONVERT TO INTENT OR PROJECTION** | Match/activity award entry points become consumers of Platform receipts for presentation. Trusted producers emit facts directly; the client never submits a reward amount. |
| `HoneyProgressionState._post_honey_grant_to_backend` fallback from activity fact to `grant_honey(amount)` | Lets a client-selected amount become a remote grant | **DELETE** | Producer fact goes to Platform through authenticated producer delivery. There is no amount-grant fallback. |
| `HoneyProgressionState.intent_spend_player_honey` | Submits amount to VS and can locally debit | **CONVERT TO INTENT OR PROJECTION** | Submit canonical catalog/action ID and relevant context. Platform calculates price, debits, and returns receipt/snapshot. |
| `HoneyProgressionState._sync_profile_to_authoritative_honey` | Overwrites local profile balance from VS response | **RETAIN** | Retain only as a projection-application adapter, renamed/documented so only verified Platform snapshots can call it. |
| `HoneyProgressionState` local-beta fallback | Mutates ProfileManager when backend is absent | **SUPPRESS** | Compile/runtime gate to isolated tests only; production and beta builds fail closed. |
| `scripts/state/hive_clan_state.gd`: `intent_record_hive_honey` and `intent_sync_member_honey_balance` | Mutates locally stored per-member Honey snapshots | **CONVERT TO INTENT OR PROJECTION** | Accept only Platform-authored display snapshots. Hive membership state is not a Honey ledger. |
| `HiveClanState.intent_debit_hive_honey_proportional` | Calculates largest-remainder member debits and can write local member/Profile balances | **CONVERT TO INTENT OR PROJECTION** | Emit a Hive purchase intent. Platform locks the authoritative membership/balance snapshot, calculates largest remainder with UUID tie-break, debits atomically, and returns the exact contribution receipt. Client keeps preview/display only. |
| `scripts/ui/main_menu.gd` Honey store helpers | Reads ProfileManager and initiates amount-based spend before granting local entitlements | **CONVERT TO INTENT OR PROJECTION** | Initiate a catalog purchase by stable product/action ID. Grant entitlement only from the committed Platform receipt. |
| `scripts/state/battle_pass_rewards.gd` Honey rewards | Routes claimed rewards into local Honey mutation | **CONVERT TO INTENT OR PROJECTION** | Platform Progression claim transaction emits/commits the Honey credit through the shared journal contract; client displays the returned receipt. |
| `scripts/arena.gd` and other activity completion callers | Invoke client Honey reward methods from local runtime observations | **CONVERT TO INTENT OR PROJECTION** | Keep local completion presentation only. Trusted match/contest services emit authoritative facts. |
| `scripts/state/vs_handshake_state.gd`: Honey balance/activity/grant/debit/Hive calls | Client transport to VS Honey authority, including client-provided amounts/member lists | **CONVERT TO INTENT OR PROJECTION** | Transport reads and allowed action intents to Platform; remove grant-by-amount and authoritative member-list semantics. |
| `tools/vs-service/src/server.ts` Honey HTTP actions | Exposes balance, activity, grant/debit, Hive preview/debit, transaction/debug endpoints | **CONVERT TO INTENT OR PROJECTION** | VS keeps only trusted fact production/outbox responsibilities. Player reads/intents move to Platform. Compatibility routes, if temporarily required, proxy without calculating or persisting and are time-bounded. |
| `tools/vs-service/src/honeyLedger.ts` | Current balance/activity policy and all Honey mutations | **DELETE** | Replace with Platform PostgreSQL account/journal/policy consumer. Preserve policy cases only as migration inputs to a frozen server policy, not as a second ledger. |
| `tools/vs-service/src/honeyLedgerStore.ts` memory/file adapters | Authoritative Honey persistence | **DELETE** | No production or beta economic authority may use them. Test fixtures should target a disposable PostgreSQL database or a clearly non-production model. |
| Honey debug grant/set/snapshot endpoints and Ops mutations | Can create arbitrary Honey value | **SUPPRESS** | Production has read-only diagnostics. Corrections require authorized, immutable adjustment/reversal events; test-only setters cannot be routed or authenticated in production. |
| Future Platform Honey transaction handler | Not present | **RETAIN** | Sole writer of Honey accounts, journal, activity receipts, Hive purchase debits, and reset adjustments. |

## Wax writers

| Current path/capability | Current mutation | Classification | Exact target treatment |
| --- | --- | --- | --- |
| `tools/rank-service/src/store.ts` `RankStore.writeEconomy` and `rank_players.wax_score` | Transactional PostgreSQL standard Wax writer; also recomputes Rank projections | **RETAIN** | Make this the Platform Wax boundary initially. All balance mutations must add immutable journal entries and shared producer receipts; derived Rank fields remain projections. |
| `tools/rank-service/src/verifiedSettlement.ts` | Applies a verified standard result with `rank_processed_events` dedupe | **RETAIN** | Adapt to the shared envelope, `(producer_service, producer_event_id)` uniqueness, payload hash, original receipt, epoch/policy checks, and immutable economic journal. |
| Rank service legacy `record_match_result`, contest, decay, recompute, and admin actions | Some accept player/action payloads and call `writeEconomy` | **CONVERT TO INTENT OR PROJECTION** | Verified producer facts remain eligible. Player-authored result/amount paths are removed; decay/recompute become scheduled Platform operations with stable event IDs and audit. |
| `RankStore.applyEconomyEpoch` | Bulk-updates Wax and clears processed events behind reset gates | **CONVERT TO INTENT OR PROJECTION** | Execute only as a participant in the coordinated epoch state machine. Write reset adjustments/journal evidence; do not erase the only replay history. |
| `rank_processed_events(dedupe_key)` | Single-key consumer dedupe | **CONVERT TO INTENT OR PROJECTION** | Migrate to shared producer identity uniqueness and canonical request hash/original response receipt. Retain old records for migration/replay safety. |
| `scripts/state/rank_state.gd` remote result/contest/decay calls | Client initiates Wax mutations | **CONVERT TO INTENT OR PROJECTION** | Standard rewards originate from verified service facts. Client keeps rank reads and possibly non-authoritative refresh intents only. |
| `RankState` local-beta result, contest, decay, debug-set, and epoch reset code | Directly mutates cached Wax with a floor and saves it | **SUPPRESS** | No beta/production fallback. Isolated calculators may remain for parity tests, but no runtime route can commit economic state. |
| `scripts/state/rank_runtime_awards.gd` | Observes local `SimRunner.match_ended`, derives outcome, and calls Rank/Crucible mutations | **CONVERT TO INTENT OR PROJECTION** | Display pending/settled state from trusted receipts. It must not originate an economic result or settlement. |
| `scripts/state/crucible_state.gd` local balance/open/settle/refund/review/earn-path paths | Complete client Wax ledger and reserve mirror | **CONVERT TO INTENT OR PROJECTION** | Retain lifecycle/display state and transport. All balances, reserve, escrow, settlement, refunds, and review resolution are Platform receipts. |
| `CrucibleState.intent_apply_competitive_wax_result` | Deprecated/suppressed standard result mutation | **DELETE** | Remove after compatibility tests are migrated. Crucible never invokes ordinary Rank award settlement. |
| `tools/vs-service/src/crucibleLedger.ts` | Legacy file/memory Wax accounts, escrow, reserve, settlement, admin review, reset | **DELETE** | Keep only temporary migration readers if required. Disable all runtime production routes before Platform enablement. |
| VS `record_competitive_wax_result` endpoint | Deprecated alternate Wax award path | **DELETE** | Remove client/server transport and route after callers/tests prove absent. |
| `tools/vs-service/src/repositories/crucibleSettlement.ts`: `setPlayerBalance` | Ops path writes VS PostgreSQL player balances | **SUPPRESS** | No production manual balance setter. Migrate seed/opening value via audited Platform epoch adjustments. |
| `PostgresCrucibleSettlementRepository.openEscrow`, `settleVerified`, `refund`, `reverse` | Correct double-entry semantics, but writes a second VS-owned Wax ledger | **CONVERT TO INTENT OR PROJECTION** | Reuse invariants and tests in Platform. VS records reservation/settlement receipt references and lifecycle only. Platform owns accounts, custody, reserve, and terminal mutation. |
| `vs_crucible_accounts`, journal, transaction, escrow, settlement, refund, reversal tables | Durable VS PostgreSQL alternate Wax authority | **CONVERT TO INTENT OR PROJECTION** | Freeze for migration/audit, reconcile, migrate opening custody/history, then make read-only. New Platform tables cannot retain FKs to VS-private tables. |
| VS Crucible reconciliation and smoke tests | Verify double-entry conservation, reversal, idempotency | **RETAIN** | Port/generalize as Platform contract tests and cross-service saga/reconciliation tests; retain VS-side receipt/lifecycle reconciliation. |
| `scripts/state/wax_reward_policy.gd` and `tools/vs-service/src/waxRewardPolicy.ts` | Duplicate standard reward calculators | **DELETE** | One Platform-owned, versioned reward policy. Client implementation may remain only as a non-authoritative display estimator if product requires it and it is visibly labeled. |
| `scripts/state/rank_wax_calculator.gd`, rank matchmaker/leaderboard/tier/percentile/decay helpers | Calculate awards or derived ordering | **CONVERT TO INTENT OR PROJECTION** | Server policy calculates mutations. Deterministic rank ordering helpers remain projections; client calculators are parity tests/display only. |
| Future Platform Crucible reservation/settlement handler and `reserve:award` account | Not present | **RETAIN** | Sole writer of available Wax, open escrow, reserve credits, refunds, reversals, and epoch adjustments. No reserve debit path. |

## Nectar writers

| Current path/capability | Current mutation | Classification | Exact target treatment |
| --- | --- | --- | --- |
| `scripts/state/battle_pass_state.gd`: award/record methods and `_apply_nectar_xp_award` | Calculates multipliers/fractional carry, increments local XP, dedupes, and saves | **CONVERT TO INTENT OR PROJECTION** | Apply authenticated Platform progression snapshots/receipts only. Server consumes trusted facts and owns amount, multiplier, carry, caps, and season. |
| `BattlePassState` quest/challenge progress and award claims | Client advances progress and grants rewards | **CONVERT TO INTENT OR PROJECTION** | Trusted services advance authoritative challenges. Genuine claim actions remain client intents; Platform validates availability and atomically commits claim plus any cross-economy reward. |
| `BattlePassState` pass entitlement, veteran start, access ticket, refund, prize, token, analytics credit methods | Client mutates progression/entitlement-adjacent state | **CONVERT TO INTENT OR PROJECTION** | Split by domain during implementation. Platform owns economic/progression effects; identity/commerce owns purchased entitlements; client projects receipts. |
| `scripts/state/battle_pass_runtime_awards.gd` | Observes local match end and directly awards Nectar/contest progression | **CONVERT TO INTENT OR PROJECTION** | Presentation only. Trusted match/contest/challenge producers emit facts to Platform; no client award trigger. |
| `scripts/state/contest_state.gd`, `scholastic_state.gd`, `ad_manager.gd`, `arena.gd`, and UI callers | Call local BattlePass mutation/claim APIs | **CONVERT TO INTENT OR PROJECTION** | Server-owned facts for awards/progress; authenticated player intents only for real claims/actions; UI reads projections. |
| `scripts/state/nectar_reward_policy.gd` | Client reward calculator | **DELETE** | Replace with one versioned Platform policy; retain golden vectors for parity/display testing. |
| `scripts/state/swarm_pass_state.gd` and `swarm_pass_nectar_pipeline.gd` | Separate local Nectar wallet, awards, claims, and save | **DELETE** | Remove after confirming the non-autoload legacy panel is unreachable or migrating any still-used presentation. Never import this as a second balance. |
| `scripts/state/economy_buff_state.gd`: `_award_nectar` and activity writers | Another local Nectar award path | **DELETE** | Remove Nectar coupling. Preserve any authorized non-economy buff behavior in a separate state boundary if still used. |
| `scripts/ui/swarm_pass_panel.gd` | Reads `/root/SwarmPassState` | **DELETE** | Remove obsolete panel/scene or point the supported Battle Pass UI at the Platform projection; do not revive the duplicate autoload. |
| `scripts/state/battle_pass_rewards.gd` | Claims can grant Honey/other rewards locally | **CONVERT TO INTENT OR PROJECTION** | Platform claim transaction owns reward eligibility and shared-journal effects; client displays the receipt. |
| Future Platform Progression fact/claim handler | Not present | **RETAIN** | Sole writer of seasonal Nectar, fractional carry, challenge state, claims, and derived pass-level projection. |

## Read and presentation paths

Read paths are not economic writers once the conversions above are enforced.
They should remain available in read-only rollout before mutations.

| Read family | Current consumers | Target |
| --- | --- | --- |
| Honey balance and transaction history | Honey HUD/widget, `main_menu.gd`, profile/settings surfaces, Hive dashboards | Platform snapshot/history API, cached locally with epoch/version; never infer authority from a displayed value |
| Hive Honey contribution preview | Hive tournament/menu flows | Platform-authored deterministic preview tied to a short-lived membership/balance version; commit may return a new allocation if the snapshot expired |
| Wax/rank snapshot and leaderboard | `rank_panel.gd`, main menu, lobby, outcome overlay, Hive display, matchmaker | Rank projection API derived from Platform Wax; client cache is replaceable |
| Crucible balance/escrow/settlement | lobby, arena, outcome overlay, Ops console | Platform balance/custody receipt plus VS lifecycle status, joined by stable contract/match/receipt IDs |
| Nectar/pass/challenges/claims | supported Battle Pass screen, outcome overlay, contest/scholastic/ad surfaces | Platform seasonal progression snapshot with season/epoch/revision |

## Reusable infrastructure decision

| Existing infrastructure | Decision | Required adaptation |
| --- | --- | --- |
| `vs_idempotency_receipts` | **RETAIN** pattern | Platform schema uses explicit producer service/event uniqueness, request hash, status, original response, side-effect reference, and timestamps. Do not merely reuse a client namespace/key. |
| `PostgresDurableCoreRepository.createContract` transaction | **RETAIN** pattern | It already claims a receipt, hashes canonical input, returns the original committed object, and rejects altered retries. Generalize transaction helpers rather than copy-paste. |
| `vs_outbox_events` and repository enqueue/ack flow | **RETAIN** | Add/standardize producer envelope and service consumer delivery. Preserve unique dedupe, request hash, attempts, pending/dead-letter state, and original event ID. |
| Immutable VS contracts, command streams, lifecycle events, and verified results | **RETAIN** | Remain authoritative evidence for producer facts and Crucible saga references. |
| Public contest/1v1 reconciliation workers and operational audit tables | **RETAIN** | Reuse worker/alert/dashboard conventions for cross-service missing receipt, stuck reservation, and outbox repair. |
| `RankStore` PostgreSQL transaction/advisory lock and audit classification | **RETAIN** | Add immutable economic journal, common receipt contract, integer units, and explicit Platform domain modules. Avoid whole-state diff writes as the long-term ledger API. |
| `rank_processed_events` | **CONVERT TO INTENT OR PROJECTION** | Migrate to canonical producer identity plus request hash and stored response. Its current single opaque key does not meet the hardened contract alone. |
| VS PostgreSQL Crucible double-entry journal and `reconcile()` | **RETAIN** semantics/tests | Re-home accounts/custody in Platform. Replace direct VS FKs with immutable external contract/result references and signed/authenticated service facts. |
| Honey memory/file adapters and legacy Crucible memory/file adapters | **DELETE** as authority | They may inform migration parsing only; production must fail closed if selected. |
| Client JSON saves | **CONVERT TO INTENT OR PROJECTION** | Keep only epoch/versioned cache and presentation state. Never upload a cached balance as truth. |

## Current-to-target writer invariant

After the authorized implementation is complete, the writer map is exactly:

| Future concept | Exactly one writer |
| --- | --- |
| Honey accounts, custody, journal, activity receipts | Platform Economy Honey transaction handler |
| Wax available balances, escrow, reserve, journal, adjustment receipts | Platform Economy Wax transaction handler |
| Nectar, fractional carry, challenge state, claim receipts | Platform Progression transaction handler |
| Rank tier/position/percentile | Rank projection builder reading canonical Wax |
| VS match/Crucible lifecycle and reservation receipt references | VS durable lifecycle repository |
| Trusted result facts | Trusted verifier/authority result repository |

No target concept has two writers.

## Contradictory or stale contracts

- `docs/economy/wax_first_pass_frame.md` previously called client `RankState`
  canonical and said the winner receives the full 2-Wax pot. It is formally
  superseded for authority/reset/settlement by ADR 001 and corrected to the
  `1800 + 200` contract.
- `docs/economy/crucible_launch_runbook.md` describes the superseded legacy
  file-store/Supabase-adapter path and configurable burn terminology. Its
  historical code notes remain useful, but it is not a launch authority.
- `docs/architecture/public_modes/registries-v1.md` already has the correct
  integer Crucible amounts and custody interpretation. ADR 001 sharpens the
  reserve into a literal Platform account with no debit path.

## Unresolved product and contract decisions

These decisions now block activation of the capability they affect, not the
deployed zero epoch or read-only Platform authority. They do not require a new
tool or third-party vendor.

1. **Wax at zero:** current client and Rank service floors/defaults are `100`.
   Confirm that Wax may remain at `0` after reset, define whether losses/decay
   floor at zero, and approve revised zero-safe reward/ranking behavior.
2. **Standard Wax schedule:** confirm which current standard, contest,
   close-loss, decay, Hive tournament, and major-event policies survive. The
   public-mode registry currently authorizes fewer rewards than local Rank code
   can calculate.
3. **Honey activity policy:** freeze trusted producer event types and the reward
   table. Remove client-submitted grant amounts.
4. **Hive purchase snapshot:** define active/inactive eligibility, debt/zero
   balance handling, snapshot expiry/retry behavior, and whether contribution is
   based on all available balances or a capped basis. Largest remainder plus
   UUID tie-break is already frozen.
5. **Honey catalog ownership:** identify the server-owned product/action catalog
   and decide whether entitlement grant commits in the same Platform transaction
   or through an idempotent commerce/entitlement saga.
6. **Nectar policy:** freeze season ID, thresholds, multiplier order, rounding,
   fractional carry, caps, premium/Elite applicability, challenge truth source,
   veteran start, and claim/reward semantics.
7. **Crucible reservation expiry:** freeze pre-start cancellation, reservation
   TTL, late verified result behavior, and automated orphan refund policy.
8. **Crucible review/reversal:** decide whether held review remains in beta and
   define the authorized correction flow without creating a reserve debit or
   manual balance edit path.
9. **Legacy data disposition:** decide whether pre-beta Honey/Wax/Nectar history
   is archived, imported as zero-net audit evidence, or discarded after backup.
   Opening beta values remain zero either way.
10. **Deployment boundary name:** approve whether the existing Rank service is
    renamed/exposed as Platform Economy/Progression or retains its process name
    while the domain modules and APIs use Platform terminology.

## Discovery exit checklist

- [x] Every located current Honey mutation family is classified.
- [x] Every located current Wax/Crucible mutation family is classified.
- [x] Every located current Nectar/progression mutation family is classified.
- [x] Current memory, file, client-save, and PostgreSQL stores are identified.
- [x] Rank/VS/client ownership overlaps are explicit.
- [x] Reusable idempotency, outbox, transaction, audit, and reconciliation code
  is identified with reuse/adaptation limits.
- [x] Each future concept has exactly one writer.
- [x] The Crucible `1000 + 1000 -> 1800 + 200` contract and literal no-debit
  award reserve are frozen.
- [x] Unresolved product decisions are listed.
- [x] Discovery stopped before implementation authorization; subsequent
  implementation, migration, deployment, backup/restore proof, and zero reset
  were executed as a separately authorized block.
