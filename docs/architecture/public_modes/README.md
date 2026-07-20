# Public Modes Package 0 — Contract Freeze

Status: Accepted for implementation planning
Release posture: `HOLD`
Date: 2026-07-18

Package 0 freezes architecture and contracts only. It changes no application behavior, backend route, database, credential, economy mutation, deployment, or feature flag.

## Governing decisions

- [ADR 001 — Player identity and session authority](adr-001-player-identity-and-session-authority.md)
- [ADR 002 — Service trust and endpoint classes](adr-002-service-trust-and-endpoint-classes.md)
- [ADR 003 — Canonical command stream and restart policy](adr-003-command-stream-and-restart-policy.md)
- [ADR 004 — Trusted match verifier](adr-004-trusted-match-verifier.md)
- [Public match contracts v1](public-match-contracts-v1.md)
- [Public contest contracts v1](public-contest-contracts-v1.md)
- [Registries v1](registries-v1.md)
- [Package 0 evidence report](package-0-evidence.md)

## Authority clarification

`OpsState`/`SimState` remains the only gameplay-state mutation authority inside any Swarmfront simulation. Public competition adds a trust distinction between:

- a player-controlled simulation, which may submit commands, hashes, and evidence; and
- a trusted headless simulation, which may issue a ranked/economic result receipt.

This supplements, and does not replace, `docs/pvp_authority_audit.md`.

## Supersession boundaries

- `docs/sf_entap_bridge_plan.md` remains valid for offline/dev and optional future platform linking. Public competitive endpoints additionally require an authenticated backend UUID session.
- `docs/vs_backend_contract.md` remains the roster-v1 compatibility contract until Package 3. Public match contract v1 in this directory defines the target roster-v2 shape.
- `docs/rank_backend_contract.md` remains the current transport contract. Its shared client bearer-token mutation design is superseded for public competition by ADR 002.
- `docs/money_game_ledger_contract.md` remains quarantined and does not authorize cash play. Package 0 covers free modes and Wax Crucible only; cash and paid async contests are out of scope.

## Product alignment amendments

1. Free async 3-map and 5-map contests allow immediate play and close atomically after four distinct authenticated players submit qualified results. They do not wait for a locked four-player lobby. Locked-before-play rosters are reserved for future economic contests.
2. In 2v2, exactly one valid friend/party pair is preserved. With zero or multiple candidate pairs, teams are rank-balanced as highest+lowest versus the two middle players.

## Package 1 entry gate

Package 1 may start only when the decisions and schemas linked above are accepted. Its entire behavior change is one authentication vertical slice for Standard 1v1 queue entry. All public and mutation flags remain false.

## Implementation evidence

- [Package 1 — Authenticated Standard 1v1 vertical slice](package-1-evidence.md)
- [Package 2 — Durable VS core](package-2-evidence.md)
- [Package 3 — Durable roster-v2 Standard 1v1](package-3-evidence.md)
- [Package 4 — Trusted Standard 1v1 result authority](package-4-evidence.md)
- [Package 5 — Standard 1v1 rank settlement candidate](package-5-evidence.md)
- [Package 6 — Human CTF and explicit bot fallback](package-6-evidence.md)
- [Package 7 — Durable non-economic contest platform](package-7-evidence.md)
- [Package 8 — Time Puzzles and weekly Gauntlet](package-8-evidence.md)
- [Package 9 — Crucible settlement correction](package-9-evidence.md)
- [Package 10 — Free async cohorts](package-10-evidence.md)
- [Package 11 — Multi-seat synchronized modes](package-11-evidence.md)
- [Package 12 — Operations and controlled rollout](package-12-evidence.md)
- [Sprint completion handoff](sprint-completion-handoff.md)
