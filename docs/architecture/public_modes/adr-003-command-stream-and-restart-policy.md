# ADR 003 — Canonical Command Stream and Restart Policy

Status: Accepted for Package 2/4
Date: 2026-07-18

## Context

The current VS process stores sessions, queues, intent streams, and acknowledgements in memory. It assigns command sequence and execution tick, but a process restart loses the accepted stream. The Godot peers run the simulation locally, so client terminal state and hashes are useful evidence but cannot authorize a public ranked or economic result.

Public matches need a durable, replayable command history with an explicit answer for every restart and partial-failure case.

## Decision

### Canonical stream

VS owns an append-only canonical command stream for each public match. Version 1 uses PostgreSQL behind a repository interface because commands are player intents rather than a row per simulation tick. A Redis or dedicated log implementation may replace the adapter only after measurement; its externally observable contract must remain the same.

An accepted command is acknowledged only after the database transaction commits. Public mode code must never acknowledge a command that exists solely in process memory.

Each event contains at least:

- `match_id` and `match_epoch`.
- Monotonic `command_seq`, allocated atomically per match.
- Caller `player_id`, derived from the authenticated session.
- `seat_id`, derived from the frozen roster.
- Client-generated `client_command_id`.
- Server-assigned `execute_tick`.
- Validated command type and canonical payload.
- `received_at` and `committed_at` server timestamps.
- Command schema version.

`(match_id, match_epoch, client_command_id)` is unique. A retry with the same ID and identical canonical content returns the original receipt. Reuse with different content is rejected as `idempotency_conflict`.

The service serializes sequence allocation per match. Command content cannot change a player, seat, team, map, rule set, or seed established by the signed match contract.

### Read and acknowledgement model

Participants request events after a known sequence number. The response declares the contiguous sequence range and current durable high-water mark. Missing sequence numbers are a protocol error, not an instruction to guess.

Client acknowledgements and state-hash reports are stored as separate evidence. They can diagnose desync and support replay selection, but they do not amend the canonical command stream.

### Durable match inputs

Before a public match can start, these inputs must be durable:

- Frozen public match contract and contract hash.
- Complete roster v2 and seat assignments.
- Mode/rules/map identifiers and content hashes.
- Seed, protocol version, simulation build ID, and match epoch.
- Lifecycle state and timing/grace deadlines.

The verifier replays from those inputs and sequence 1. Trusted checkpoints may be added later as an optimization, but a checkpoint cannot replace the retained canonical stream in version 1.

### Failure behavior

- If durable storage is unavailable before commit, VS rejects or pauses the action; it does not accept locally.
- If the response is lost after commit, the client retries the same `client_command_id` and receives the prior receipt.
- If a command stream has a gap, corrupt event, incompatible schema, or hash mismatch, verification stops and the match becomes `NO_CONTEST`.
- No rank or economy consumer may infer a result from partial commands, a client-reported winner, or the last in-memory state.

### VS restart

On restart, VS reconstructs each active match from its durable contract, lifecycle record, command high-water mark, acknowledgements, and server deadlines.

- A compatible match with a complete stream returns to `RECONNECTING` and permits roster members to resume within the stored grace deadline.
- Expired player grace is resolved by the server lifecycle policy and recorded as a terminal forfeit event.
- A missing or incompatible contract/stream cannot resume and is closed as `NO_CONTEST` with an explicit reason.
- Restart does not reset a grace deadline, increment the epoch, reassign seats, or replay an economy mutation.

### No-contest policy

`NO_CONTEST` is authoritative, terminal, and non-winning. It produces no rank win/loss and no reward. If escrow exists, settlement policy consumes the no-contest receipt and performs an idempotent refund unless a later fraud/review policy explicitly overrides it.

Version 1 reason codes are:

- `AUTHORITY_STORAGE_FAILURE`
- `COMMAND_STREAM_GAP`
- `COMMAND_STREAM_CORRUPT`
- `CONTRACT_MISSING`
- `CONTRACT_HASH_MISMATCH`
- `CONTENT_UNAVAILABLE`
- `PROTOCOL_INCOMPATIBLE`
- `VERIFIER_FAILURE`
- `VERIFIER_DISAGREEMENT`
- `ADMINISTRATIVE_CANCELLATION`

A disconnect by one player is not automatically no-contest. Once the server-owned grace deadline expires, it becomes a verified `FORFEIT`, provided the contract and lifecycle evidence remain valid.

### Retention and recovery

Contracts, commands, terminal receipts, and settlement references are retained together until result verification, all side effects, appeal/review time, and configured retention have completed. Package 2 must set and test the concrete retention interval before public release. No cleanup job may remove evidence for a non-final match or unsettled result.

Backups must support point-in-time recovery. Restored commands retain original IDs and sequence numbers; recovery must not republish already completed side effects outside their idempotency namespaces.

## Implementation boundary

Package 2 adds the durable repository and lifecycle behavior. Package 3 consumes it from roster-v2 Standard 1v1, Package 4 adds verified result authority, and Package 11 extends the proven contract to multi-seat modes. The adapter location should remain within the VS service (for example `tools/vs-service/src/repositories/`) until measured load justifies a separate stream service.

## Release gate

Before any public flag can open, load and restart tests must prove:

- Zero acknowledged-command loss across forced VS/database restarts.
- Contiguous replay for every completed test match.
- Stable idempotent receipts after ambiguous network failure.
- Deterministic resume, forfeit, or no-contest outcomes.
- Capacity headroom at the declared public concurrency target.

Exact latency and capacity thresholds belong in the Package 2 operational SLO, not in this architecture decision.
