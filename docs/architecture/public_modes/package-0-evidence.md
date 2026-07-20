# Package 0 Evidence Report

Date: 2026-07-18
Package result: `PASS` for architecture/contract freeze
Public release result: `HOLD`

## Scope completed

Package 0 produced documentation only:

- Player identity/session issuer decision.
- Player, service, verifier, admin, public, and debug trust classes.
- Durable canonical command-stream and restart/no-contest policy.
- Trusted headless match-verifier decision.
- Public match contract, roster v2, and sync result v1.
- Public contest lifecycle and attempt/result contract.
- Comparator, mode, contest, idempotency, and protocol registries.
- Repository-shaped package sequencing in `docs/public_modes_readiness_program_sharpened.md`.

No runtime code, scene, resource, migration, secret, service configuration, deployment, or feature flag was changed by this package.

## Code-grounded findings retained by the freeze

| Finding | Repository evidence | Package 0 response |
|---|---|---|
| VS trusts body identity on ordinary actions and models only host/guest | `tools/vs-service/src/server.ts` | ADR 001/002; roster v2 contract |
| VS queue/session/intent state is process memory | `tools/vs-service/src/server.ts` | ADR 003 durable PostgreSQL repository boundary |
| VS orders commands but does not simulate a winner | `tools/vs-service/src/server.ts` | ADR 004 separate headless verifier |
| Deterministic gameplay runs in Godot and client peers exchange hashes | `scripts/state/vs_pvp_runtime.gd`, `docs/pvp_authority_audit.md` | Keep `OpsState`/`SimState`; replay it in trusted worker |
| Rank identity and UUIDv7 allocation already live in rank service/PostgreSQL | `tools/rank-service/src/server.ts`, `tools/rank-service/src/store.ts`, `tools/rank-service/src/sql/migrations/003_player_identity.sql` | Reuse rank service as initial identity/session issuer |
| Rank mutations largely use shared bearer authority | `tools/rank-service/src/server.ts`, `docs/rank_backend_contract.md` | Separate player JWT, service JWT, and ops identity classes |
| Money/Crucible and async adapters are quarantined/dev-shaped | `tools/vs-service/src/crucibleLedger.ts`, `tools/vs-service/src/economyQuarantineSmoke.ts`, `docs/money_game_ledger_contract.md` | Crucible remains gated until Package 9 durable settlement |
| Contest definitions/leaderboards are client/static/local shaped | Godot contest resources and `user://` ContestState paths | Server-owned contest v1 and comparator registry |
| Remote ops URL and paid/rank gates are disabled | Current ops configuration and economy guards | Keep all public/mutation flags false |

## Frozen product interpretations

1. Free rolling async play begins immediately and closes atomically on four distinct qualified authenticated players.
2. Free async v1 permits one scored attempt per player per cohort; ambiguous transport retries do not consume another attempt, and server-voided infrastructure failures can receive an audited replacement.
3. 2v2 preserves exactly one verified friend pair. Zero or multiple pairs use highest+lowest versus the middle two. 3P FFA, 2v2, and 4P FFA start unranked with shadow analytics.
4. Crucible uses integer milli-Wax: 1000 per player reserved, 1800 to the verified winner, and 200 to a separately audited award pot. Buffs are disabled.
5. Human CTF starts unranked; bot CTF/HCTF is an explicitly accepted practice diversion after a wait threshold, never a silent ranked conversion.
6. Human HCTF stays held until hidden information has live trusted authority; post-match replay alone is insufficient.
7. Period leaderboards project one best result per canonical player.

## Package 1 implementation entry criteria

Package 1 is intentionally narrow:

- Add device credential/session persistence and token issuance to `tools/rank-service`.
- Add Godot secure-credential/session seams.
- Authenticate one Standard 1v1 queue-entry vertical slice.
- Derive player ID from token subject and reject mismatching body UID.
- Leave every public, rank-mutation, contest, and economy flag false.

Package 1 does not need roster v2, the verifier, or public UI activation to prove this slice.

## Unresolved release blockers

- No vetted native iOS/Android non-exportable key integration exists yet.
- Existing beta identity migration, all-devices-lost recovery, revocation UX, and privacy policy require implementation/approval.
- The match-authority worker and reproducible headless build pipeline do not exist.
- PostgreSQL command-stream throughput, retention interval, restore behavior, and operational SLO are unmeasured.
- Roster v2 has not been implemented across VS/Godot.
- Service/admin key management and rotation are not implemented.
- Crucible ledger persistence, reconciliation, award-pot custody/reporting, and signed settlement are not implemented.
- Server-backed contest definitions, attempt grants, result verification, leaderboard projection, and outbox messaging are not implemented.
- Human HCTF lacks a live hidden-information authority.
- Remote-config publication/rollback and production telemetry/alerts are not ready.

These are expected future-package gates. Package 0 passing does not make any mode ready for the public.

## Validation evidence

Executed after the contract freeze:

- Local Markdown-link resolution across `docs/architecture/public_modes/*.md`: `PASS`.
- New-file whitespace check using `git diff --no-index --check`: `PASS`.
- Direct trailing-whitespace scan across the package and sharpened program: `PASS`.
- Package file-type check: `PASS`; `docs/architecture/public_modes/` contains Markdown only.
- Scoped `git status`: only the new Package 0 documentation and sharpened program are reported in the documentation scope. Existing unrelated worktree changes were not edited by this package.

No build, migration, service, or gameplay smoke was required because Package 0 changes no executable or configuration input. Those tests become mandatory with Package 1 code.

## Rollback

Package 0 has no runtime rollback. Reverting only `docs/architecture/public_modes/` and the Package 0 amendments in `docs/public_modes_readiness_program_sharpened.md` removes this freeze. Runtime state and user data are unaffected.
