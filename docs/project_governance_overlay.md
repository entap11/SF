# Project Governance Overlay — Swarmfront

**Status:** Adopted with Software Engineering Governance Constitution v2.0  
**Effective date:** 2026-09-03  
**Repository:** `project`  
**Universal governance:** `docs/coding_governance.md`

This overlay is the project-specific companion required by the universal Constitution. It preserves the stricter Swarmfront rules that governed the repository before Constitution v2.0 was adopted. If this overlay is more specific or stricter, follow it. It may not weaken the Constitution without a written waiver.

## 1. Identity and reliability profiles

- Purpose: deterministic real-time strategy game, player identity, public multiplayer, contests, progression, and opt-in analytics.
- Supported development/runtime environment: Godot 4.2 family on macOS; the accepted mobile engine/export evidence uses Godot 4.2.2.
- Current field target: iPhone/TestFlight beta. Android is not field-supported until a separate device gate records approval.
- Hosted environments: local development and explicitly identified Render staging services. Production promotion requires its own release evidence.
- Baseline profile: presentation, disposable UI state, local visual preferences, and non-consequential tooling.
- Transactional profile: player profile persistence, matchmaking/session writes, contest participation, progression, and telemetry ingestion.
- Field Critical profile: player identity/session authority, verified public results, Rank/Wax/Honey/Nectar effects, paid entry/escrow/settlement/refund, client publication, and protected evidence.

## 2. Stack and canonical entry points

- Game runtime/framework: Godot 4.2/GDScript. Main scene: `res://scenes/Shell.tscn`.
- Simulation authority entry point: `scripts/ops/ops_state.gd`; owned game graph: `scripts/state/game_state.gd`.
- Node services: TypeScript/Node packages under `tools/analytics`, `tools/match-authority`, `tools/rank-service`, `tools/scholastic-service`, and `tools/vs-service`.
- Primary package manager for every Node package: npm. Each package owns and must use its committed `package-lock.json`; CI/candidate installs use `npm ci`.
- Persistent hosted authorities: PostgreSQL for Rank/identity, durable VS/public-mode state, scholastic state, and analytics where the relevant hosted service is enabled.
- Deployment definition: `render.yaml` for the declared Render staging resources. A local file or memory adapter is never silently promoted to production authority.
- Canonical game checks: `scripts/dev/run_release_readiness_gate.sh` and the focused Godot smoke tests under `tools/`.
- Canonical Node build: `npm ci && npm run build` within each deployed package.

The exact Node major/minor and npm version are not yet pinned repository-wide. This is adoption debt recorded in `docs/governance_v2_adoption_audit_2026-09-03.md`, not permission to use arbitrary release runtimes.

## 3. Authoritative state and module boundaries

Swarmfront maintains one authoritative gameplay state: `OpsState`/`GameState` (historically also called `SimState`).

- Only simulation/state systems may mutate hives, lanes, units, ownership, power, selection used by simulation, capture state, match phase, outcome, or authoritative match statistics.
- UI, input, render, menu, diagnostics, and overlay code may read snapshots and emit intents. They must not mutate gameplay objects or `OpsState` fields directly.
- All mutation must pass through the owning authority boundary. A public method on `OpsState` is not sufficient by itself if it merely exposes arbitrary mutation to a presentation caller.
- Visual state must never be used to infer gameplay state.
- Simulation behavior must be deterministic and independent of render-frame frequency.
- Logging is event-driven, bounded, and redacts credentials/private data; it is not emitted every frame.

Layer ownership remains separate:

- Handshake/matchmaking finds eligible players and establishes a session. It does not choose maps, randomize gameplay, start countdowns, award prizes, or execute gameplay.
- Session setup records participants, mode/session identity, and the authority for the next transition.
- Pregame setup owns shared map/rules/randomizer/countdown decisions and publishes them once.
- Gameplay runtime consumes the agreed setup and advances the match.
- Postgame owns result presentation, rewards, reports, replay, and progression requests; authoritative services decide consequential outcomes.

Crossing one of these boundaries requires an explicit contract and tests. Shared context carries only facts required by the current authority. Random or derived shared values are produced by their owning layer and either seeded from agreed session state or published once by that authority.

## 4. Authority Registry

| Material fact | Canonical authority and identity | Authorized writer | Effective semantics/evidence | Consumers and correction/rebuild |
|---|---|---|---|---|
| In-match gameplay state | `OpsState`/`GameState`, match ID + epoch/tick | Simulation systems through owned `OpsState` intents/mutations | Effective at the accepted deterministic simulation tick; state hash/event evidence where required | Render/UI/telemetry read projections; rebuild by deterministic replay for verified modes |
| Public match contract, roster, lifecycle, and command stream | VS PostgreSQL durable-core tables, match ID + epoch | Authenticated VS repository transactions | Effective only after transaction commit; immutable contract hashes and ordered events | Game clients and verifier; reconnect/refetch by match/epoch; corrections use new lifecycle/result evidence |
| Verified public match result | Trusted match verifier receipt persisted by VS, result ID | Match-authority worker via dedicated verifier credential | Effective after deterministic double replay or trusted server lifecycle result and VS commit | Rank/economy/contest consumers; invalid or ambiguous evidence resolves to explicit no-contest/review state |
| Player identity and device-backed session | Rank/ENTaP PostgreSQL identity tables, player UUID/device/session IDs | Identity service transactions | Effective after commit; device challenge, key fingerprint, and session evidence retained | VS and game consume signed player tokens; revocation/correction is additive |
| Rank and canonical player Wax | Rank/ENTaP PostgreSQL state plus processed-event/audit records, player ID + event ID | Rank service verified settlement/economy repositories | Effective after committed idempotent transaction under enabled capability and epoch | Game/VS/leaderboard projections refetch; corrections use governed events rather than history rewrite |
| Platform Honey/Nectar/economy effects | Rank/ENTaP platform-economy ledger, epoch + operation/request ID | Authorized platform-economy service routes | Effective after committed idempotent ledger transaction | Game and VS read receipts/balances; replay by original operation ID |
| Public contest definition, attempt, result, placement, and messages | VS PostgreSQL public-contest tables, contest/attempt/result/message IDs | Admin publication, authenticated entry, verifier result, and reconciliation transactions | Effective after commit using server time and frozen definition/comparator hashes | Game/dashboard read projections; deterministic comparator rebuild and additive replacement evidence |
| Paid entry/escrow/settlement/refund | Approved production ledger authority identified by the money-game contract; local memory/file ledgers are test adapters only | Authenticated ledger service transaction with idempotency key | Effective after authoritative commit; append-only transaction journal | Client/ops projections; reconcile by operation ID and correct additively |
| Local player preferences and recoverable non-competitive profile | `ProfileManager` scoped `user://` record, profile/schema version | Profile manager APIs | Effective after atomic local save; not authoritative for server-governed identity/economy | UI reads; migrate/version or explicit reset |
| Analytics event acceptance | Analytics PostgreSQL event table, event ID | Bounded authenticated/approved ingest route | Effective after committed insert/dedupe | Rollups/dashboard are rebuildable projections; source events are not gameplay authority |

Detailed public-mode authorities, protocol versions, and idempotency namespaces remain canonical in `docs/architecture/public_modes/registries-v1.md`. Money-specific invariants remain canonical in `docs/money_game_ledger_contract.md`.

## 5. Domain invariants and bounded implementation

- Build the smallest universal mechanic that satisfies confirmed scope. Do not bundle adjacent rules, UI, persistence, monetization, matchmaking, randomization, telemetry, or diagnostics without explicit scope.
- Prefer reusable primitives over mode-specific shortcuts.
- Do not change gameplay rules or constants without explicit instruction.
- Keep orchestration thin. Extract helpers only around stable responsibilities with narrow contracts; do not move complexity sideways.
- Prefer existing project patterns and local helper APIs.
- For non-trivial, architecture-sensitive work, record the requested behavior, owner, explicit exclusions, and acceptance evidence before implementation. Obtain confirmation before expanding beyond that boundary.
- Do not refactor unrelated domains because nearby code is imperfect.
- If existing code violates governance, do not expand the violation. Isolate it or record a bounded remediation.

## 6. Mutation Registry

This registry covers mutation families. New consequential/final endpoints or client flows must add a specific entry here or to an explicitly referenced domain registry before release.

| Mutation family | Write class | Data class | Privacy class | Authority | Idempotency/recovery |
|---|---|---|---|---|---|
| Input/pointer/game commands | Consequential Event within a match | Class 1 for local practice; Class 2 for verified public evidence | Internal/player-private | `OpsState` locally; VS command stream for public matches | Stable client command ID; ordered stream; reconnect/refetch/replay |
| Identity register/session/revoke | Final Transition | Class 2; credentials are secret | Client-private/credential | Rank identity PostgreSQL | Request/challenge/session IDs; uniqueness; revocation evidence |
| Public queue/session lifecycle | Consequential Event | Class 2 | Client-private/internal | VS PostgreSQL durable core | Caller request/lifecycle IDs; durable receipt; resume/reconcile |
| Verified result commit | Final Transition | Class 2 and Class 3 when it drives value | Internal/financial where applicable | Trusted verifier result persisted by VS | One result per authority subject; signed immutable receipt; no-contest on ambiguity |
| Rank/progression award | Consequential Event | Class 3 when convertible/value-bearing; otherwise Class 2 | Client-private/financial | Rank/ENTaP ledger | Stable verified event ID; processed-event uniqueness; refetch receipt |
| Honey/Nectar/Wax spend, reserve, settle, refund | Final Transition | Class 3 | Financial/client-private | Rank/ENTaP or explicitly approved production ledger | Required operation ID; transactional uniqueness; durable outbox/worker reconciliation |
| Public contest publish/enter/submit/close/ack | Consequential or Final Transition by action | Class 2; Class 3 if rewards attach | Public plus client-private evidence | VS public-contest PostgreSQL | Namespace registry IDs; server time; version/hash concurrency; deterministic close |
| Analytics event batch | Reversible/Consequential evidence ingestion by event type | Class 1 or 2 | Internal/client-private; no secrets | Analytics PostgreSQL | Stable event ID dedupe; offline queue retained until confirmation |
| UI filters/expanded panels | Ephemeral UI | Class 0 | Public/internal | Owning UI component | No durability required |
| Meaningful local form/profile draft | Durable Draft | Class 1 | Client-private | Owning profile/draft store | User-scoped local persistence; visible recovery; explicit discard |

## 7. Persistence, database, and security rules

- Checked-in ordered SQL migrations under each service package are the only normal production schema path.
- Migration commands must identify the target environment and fail closed. Destructive beta resets also require the gates and procedures in `docs/beta_economy_reset_deploy.md`.
- Memory, embedded, and file-backed stores are disposable/test adapters unless a contract explicitly scopes them to local non-consequential state.
- Service/admin/private keys never ship in the Godot client. Public clients receive only scoped short-lived player credentials where approved.
- Secrets are supplied by untracked local environment files or managed secret stores. They are never committed, given non-empty repository defaults, or passed as command-line values.
- Corrections to identity, contest, result, or economy evidence are additive and attributable. Current configuration must not rewrite historical effective values.
- Logs, telemetry, dashboards, exports, and test artifacts must apply both integrity and privacy classification.

## 8. Generated-file governance

| Artifact | Canonical generator/input | Canonical output | Commit/freshness rule |
|---|---|---|---|
| Godot import metadata/cache | Godot 4.2 importer from source assets | committed `*.import` metadata where already tracked; `.godot/` cache local | Do not hand-edit; release import verifies required outputs |
| Analytics JavaScript | `npm run build` from `tools/analytics/src` and `tsconfig.json` | `tools/analytics/dist` | Currently committed; regenerate, never hand-edit, and require a clean build diff |
| Other Node JavaScript | Each package `npm run build` | package `dist/` | Uncommitted artifact; build from exact source/lockfile for candidate |
| Performance reports/baselines | Canonical Godot harness/package scripts and declared fixture inputs | `artifacts/`/`debug_reports/` or approved baseline paths | Runtime reports remain ignored unless an approval workflow explicitly promotes exact evidence |
| iOS export/Xcode products | Approved Godot 4.2.2 export/template inputs | exported Xcode project/app/archive | Do not infer source truth from generated export; retain exact candidate identity and signing evidence |
| App icons | `tools/generate_ios_icons.sh` plus branding source | platform icon assets | Regenerate through the script; inspect before candidate promotion |

Duplicate numbered/conflict copies that can affect build or runtime are blockers.

## 9. Test and release contract

- Fast game gate: `scripts/dev/run_release_readiness_gate.sh --matrix-gate fast`.
- Integration/release candidate game gate: `scripts/dev/run_release_readiness_gate.sh --matrix-gate pr`, adding `--include-tf-preflight` for TestFlight and the affected domain smoke tests named in its contract.
- Performance/soak gate: `scripts/dev/run_soak_gate.sh` plus the approved performance harness/profile.
- Node package install/build: `npm ci && npm run build`; run every affected package's smoke/replay/concurrency suite.
- Public-mode field gate: the staging certification plan/evidence under `docs/architecture/public_modes/`; flags remain disabled until the exact package gate passes.
- Field Critical claims require a real supported-device/network pilot. A headless or simulator pass is Implementation Complete evidence, not Field Validated evidence.
- Candidate deployment uses the exact approved artifact and records commit/build, Godot/Node runtime, lockfile identities, schema/migration identity, environment, and feature flags.

The current repository does not yet expose the Constitution's full `format:check`, `lint:correctness`, `typecheck`, `check:generated`, `check:fast`, `check:field`, and `check:release` command surface across all packages. That is tracked adoption debt, not a waived gate.

## 10. Collaboration profile

- One substantive agent task normally uses one branch/worktree.
- The integration owner is the human/operator invoking integration unless explicitly delegated.
- Only the integration owner may mutate a shared local database, run a shared persistent generator, or promote generated evidence.
- Concurrent work must not silently edit the same authority/generated files. Agents report those files before integration.
- Development servers use assigned ports; finite tests are preferred to redundant persistent watchers.
- Integration is accepted only after the combined state passes the applicable gates.

## 11. Active waivers

No Constitution v2.0 waivers are approved by this overlay. Known gaps are recorded in the adoption audit and must not be interpreted as authorization to add new debt.
