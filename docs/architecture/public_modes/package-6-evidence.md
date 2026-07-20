# Package 6 Evidence Report — Human CTF and Explicit Bot Fallback

Program mapping: Code-grounded readiness Program Package 7  
Date: 2026-07-19  
Visible human CTF implementation result: `PASS WITH DEVICE/STAGING GATES`  
Bot CTF/HCTF practice implementation result: `PASS WITH DEVICE/STAGING GATES`  
Human HCTF result: `HOLD`  
Public release result: `HOLD`

## Delivered

- The authenticated durable two-seat queue now distinguishes `STANDARD_1V1`,
  `CTF_1V1`, and separately gated `HCTF_1V1`. Compatibility matching includes
  the mode, protocol/build, simulation build, ruleset/map IDs and SHA-256 hashes,
  authority tier, and rank policy.
- Human CTF freezes an unranked, non-economic `CTF_1V1` contract with canonical
  server seats/colors. Its client presentation is `CAPTURE_FLAG`; it cannot be
  matched against Standard 1v1 or HCTF.
- Visible CTF is accepted by the trusted verification repositories and the real
  Godot authority replay. Replay applies the CTF territory/rules configuration,
  uses the frozen contract seed, and produces a deterministic signed-result
  input. HCTF and bot contracts remain unsupported by this post-match verifier.
- Live durable matches now submit their terminal diagnostics from Arena, poll the
  durable verification result, and show pending/completed/review state in the
  outcome UI. Client winner claims remain diagnostic; the replay result is
  authoritative.
- Authenticated clients select the durable path for human 1v1/CTF/HCTF when the
  authoritative transport and player token are present. Local development keeps
  the legacy/local path available when those prerequisites are absent.
- The client resolves the contract map ID to exactly one bundled artifact,
  verifies its file SHA-256 against the frozen map hash, and refuses launch on a
  missing, ambiguous, or mismatched artifact.
- Bot diversion is based on server ticket creation time, not a client clock.
  Before the configured threshold the offer is ineligible. Acceptance is an
  authenticated, idempotent server action that cancels the human queue ticket and
  creates a different `CTF_BOT` or `HCTF_BOT` contract.
- The timeout dialog exposes all three required choices: keep searching, use the
  selected-mode bot, or cancel search. It never silently converts the queue.
- Bot contracts use server-owned canonical bot profile IDs and freeze
  `practice=true`, `bot_fill=true`, rank policy `NONE`, and economy policy
  `NONE`. The source CTF/HCTF ruleset and map hashes are retained.
- Explicit free-roll buttons are labeled `CTF BOT` and `HIDDEN CTF BOT`; the
  existing Shell hidden-CTF bot route is also classified as unranked,
  non-economic practice with a canonical bot ID.
- Client runtime Rank awards are blocked for durable, unranked, and practice
  contexts. Practice/economic classification is propagated into reward context,
  and Honey match rewards fail closed when the contract is non-economic. The
  server Rank reconciler remains restricted to verified `STANDARD_1V1` contracts
  with the exact enabled rank policy, so CTF and bot modes cannot create its
  settlement jobs.
- Independent release controls were added for visible CTF, human HCTF, live HCTF
  secrecy certification, and CTF bot fallback. Every control defaults false; no
  production flag, migration, service deployment, or external write was made.

## HCTF hard-gate result

Human HCTF remains `HOLD`. The current peer simulation can receive or derive the
hidden flag state, and a post-match deterministic replay does not prevent a peer
from inspecting packets, scene/resource state, logs, replay material, seeds, or
debug tooling during play.

The public endpoint requires both `VS_ENABLE_PUBLIC_HCTF=true` and
`VS_HCTF_LIVE_SECRECY_CERTIFIED=true`; the default false secrecy control returns
`human_hctf_secrecy_not_certified`. This flag is a release interlock, not proof by
itself. Public HCTF must not be authorized until a live trusted authority withholds
opposing hidden placement and the full inspection matrix demonstrates that the
peer cannot derive it. HCTF bot practice may proceed because there is no opposing
human client receiving hidden information.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–005 under embedded PostgreSQL: `PASS`.
- Durable queue/repository smoke: `PASS`; human CTF mode/hash isolation, explicit
  server-threshold bot acceptance, canonical bot ID, practice/rank/economy
  classification, source-ticket cancellation, restart persistence, and
  idempotency were verified.
- Authenticated HTTP smoke: `PASS`; human CTF queued, early HCTF failed with the
  secrecy reason, server bot offer was explicit, and accepted practice returned
  `CTF_BOT` with no rank/economy policy.
- Verification, Standard 1v1 release/settlement, durable core, player auth,
  economy quarantine/fail-closed, spectator, multiplayer roster, public Rank,
  and the legacy VS service suites: `PASS`.
- Match-authority TypeScript build: `PASS`. The real Godot CTF replay fixture ran
  twice with the same final state hash, winner, and elapsed tick (`PASS`).
- Godot 4.2.2 project parse/import check: `PASS`.
- Godot durable handshake, non-1v1 roster, runtime Rank quarantine, outcome UI,
  CTF rules, hidden-CTF map rules, and both Game Hub layout suites: `PASS`.
- Rank TypeScript build and verified-settlement regression: `PASS`.
- Production dependency audits for VS, Rank, and match authority: `PASS`; zero
  reported vulnerabilities at the configured audit threshold.

## Deliberate boundaries and outstanding release evidence

- Visible CTF is a code-level beta candidate, not public release authorization.
  Two physical devices have not yet completed search, ready/start, CTF play,
  disconnect/reconnect, terminal submission, authority completion, and retrieval
  against a deployed candidate.
- No managed PostgreSQL environment has applied migration 005. Backup/restore,
  service interruption during queue/bot acceptance, and restart reconciliation
  still need staging evidence.
- The exact production CTF rules and map artifacts have not been selected and
  hashed into deployment configuration. Client bundle and authority manifest
  hashes must be generated from the same immutable bytes.
- The fallback threshold defaults to 30 seconds but remains an operations/product
  value. Metrics for offer rate, continued searches, cancellations, acceptance,
  verification latency, and failures are not yet on the operations dashboard.
- Human and bot CTF have no leaderboard in this package. If boards are added
  later they must use distinct mode/practice scopes; bot results cannot appear on
  a human board.
- HCTF has no live hidden-information authority and remains held regardless of
  its visual concealment behavior.

## Staging and physical-device gates

- Apply migrations 001–005 to an isolated managed-PostgreSQL clone and exercise
  deploy/rollback with waiting human tickets and accepted bot contracts present.
- Publish immutable CTF map/rules artifacts to both the client build and authority
  manifest; prove valid hashes launch and a one-byte mismatch fails closed.
- Run iOS/iOS, Android/Android, and mixed iOS/Android visible CTF, including
  timeout choices, cancellation, continued search, bot acceptance, app restart,
  disconnect grace, verified finish, and retrieval of the same signed result.
- Confirm through Rank, Honey, contest, and economy audit stores that human CTF
  and both bot modes produce zero prohibited mutations.
- Perform an HCTF adversarial inspection exercise only after a live hidden-state
  authority exists; do not use the visual hidden-flag smoke as release evidence.

## Rollback

- Keep `VS_ENABLE_PUBLIC_CTF=false`, `VS_ENABLE_PUBLIC_HCTF=false`,
  `VS_HCTF_LIVE_SECRECY_CERTIFIED=false`, and
  `VS_ENABLE_CTF_BOT_FALLBACK=false`.
- If a staging rollout is stopped, disable new enqueues/offers while preserving
  existing contracts, queue tickets, lifecycle events, reports, receipts, and
  command streams for reconciliation. Do not drop migration 005.
- Standard 1v1, CTF, HCTF, and bot controls remain independent; disabling one
  does not authorize another mode or any reward mutation.

## Proposed next package

Build the durable non-economic contest platform shared by weekly/monthly/seasonal
time puzzles, weekly Gauntlet, and four-entry async cohorts before restructuring
Dash. The service should own contest definitions, cohort membership, best-result
deduplication, closure, top-three notifications, and leaderboard projections.
