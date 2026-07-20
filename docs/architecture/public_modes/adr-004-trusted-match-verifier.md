# ADR 004 — Trusted Match Verifier

Status: Accepted for Package 4
Date: 2026-07-18

## Context

Godot already runs deterministic `OpsState`/`SimState` gameplay, hashes state, and supports rollback. Today that simulation runs on a player's device. VS canonicalizes inputs but does not calculate a winner. Trusting a client terminal state would make rank and Wax settlement forgeable.

## Decision

### Authority tiers

`RELAY_ATTESTED` means VS owns the authenticated roster, frozen contract, canonical command order, connection lifecycle, and collected client hashes, while player-controlled clients run the simulation. Matching client reports may support development, internal testing, or an explicitly unranked closed beta. A conflict becomes no-contest plus diagnostic evidence. This tier cannot produce public rank or economy effects.

`AUTHORITY_VERIFIED` adds the trusted replay described below. Public ranked or economic results require this tier. The authority tier is frozen in the match contract; a match cannot promote itself after play.

### Service boundary

Add a separately deployed `tools/match-authority` worker. Its first implementation is a post-match verifier, not a live game server.

The worker runs a pinned headless Godot build containing the same `OpsState`/`SimRunner` gameplay authority used by the client. It leases an idempotent verification job and reads:

- The immutable public match contract and contract hash.
- The complete canonical command stream.
- Server lifecycle events, including disconnect deadlines and forfeits.
- The exact simulation build, map, rule, and content hashes named by the contract.

It replays the match from tick zero and produces one signed sync-result-v1 receipt.

### Result authority

Only either of these paths may produce a public synchronous result:

1. `SIM_REPLAY`: the trusted worker completes deterministic replay and derives placements/winner from terminal simulation state.
2. `SERVER_LIFECYCLE`: the trusted lifecycle record proves a forfeit or no-contest condition; the worker validates the record and signs the terminal receipt.

Client winner, elapsed time, final hash, and replay files are diagnostic inputs only. They never authorize rank, leaderboard, escrow, payout, or refund.

### Determinism and compatibility

The worker must load the exact `sim_build_id`, `protocol_version`, map hash, rules hash, and command schema required by the contract. It fails closed if any artifact is absent or mismatched.

The final receipt includes the replayed final state hash, final command sequence, canonical command-log hash, worker build, simulation build, and contract hash. A client/server hash disagreement is recorded for diagnostics; the trusted replay remains authoritative if the trusted inputs are complete. Two trusted replays that disagree result in `NO_CONTEST:VERIFIER_DISAGREEMENT` and an operational alert.

### Signing and consumption

The worker signs the canonical result receipt using a dedicated asymmetric verifier key in service secret storage. The receipt declares `kid`, algorithm, issued time, result ID, and payload hash. Rank, contest, and ledger consumers verify the signature, expected audience/purpose, schema version, and immutable result ID before applying a side effect.

Signing authority is unavailable to Godot clients, VS player routes, and administrators using normal operations credentials.

### Job semantics

Verification jobs are at-least-once. `match_id + match_epoch` identifies the one terminal verification subject, and `result_id` identifies the immutable outcome. Reprocessing identical inputs returns the same logical result. Conflicting terminal results are quarantined and cannot settle.

A worker crash leaves the job retryable. A permanently unavailable/incompatible artifact exhausts the declared retry policy and produces an operationally authorized no-contest path; it never falls back to a client result.

### Scope limits

- Version 1 does not simulate live on the server.
- It does not provide fog-of-war or hidden-information secrecy during play.
- Human HCTF therefore remains `HOLD`; a post-match verifier fixes result trust but cannot stop a peer from inspecting hidden state.
- Bots can be authoritative only when their commands are generated from a pinned, reproducible bot implementation included in the verified inputs.

## Required proof before public use

- Golden replays produce identical terminal hashes across supported worker hosts.
- Mutated command, map, rule, seed, and contract fixtures are rejected.
- Crash/retry produces one immutable receipt and one set of downstream effects.
- Forfeit and no-contest fixtures exercise every reason code.
- Worker key rotation accepts the declared overlap and rejects retired/unknown keys.
- Replay throughput meets the declared queue-delay SLO at public concurrency.

## Consequences

Package 4 is the trust gate for Standard 1v1. Other synchronous modes cannot be public merely because their UI and matchmaking work. Crucible additionally waits for escrow/settlement gates; human HCTF additionally waits for a live hidden-information authority design.
