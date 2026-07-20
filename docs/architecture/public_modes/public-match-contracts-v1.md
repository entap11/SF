# Public Match Contracts v1

Status: Frozen for implementation
Date: 2026-07-18

This document freezes the target synchronous public-match envelope, roster v2, and result v1. It is a logical schema; Package 2/4 will add concrete JSON Schema, TypeScript validation, SQL, and Godot decoding from these fields.

## 1. Public match contract

The server creates and freezes the contract before `RUNNING`. IDs are opaque strings at API boundaries; new internal IDs use UUIDv7.

| Field | Type | Rule |
|---|---|---|
| `contract_id` | UUID | Immutable contract identity |
| `match_id` | UUID | Immutable match identity |
| `legacy_session_id` | string/null | Read-only compatibility reference |
| `protocol_version` | integer | `2` for roster v2 |
| `command_schema_version` | integer | `1` |
| `result_schema_version` | integer | `1` |
| `minimum_client_build` | string | Server-published compatibility floor |
| `sim_build_id` | string | Exact replayable simulation artifact |
| `mode_id` | enum | Value from the mode policy registry |
| `ruleset_id`, `ruleset_hash` | string | Exact rules artifact and SHA-256 |
| `map_id`, `map_hash` | string | Exact map artifact and SHA-256 |
| `seed` | unsigned 64-bit string | Decimal string on JSON transports |
| `authority_tier` | enum | `RELAY_ATTESTED` or `AUTHORITY_VERIFIED` |
| `match_epoch` | integer | Starts at 1; changes only for a newly contracted match |
| `roster` | roster v2 | Frozen before play |
| `required_players` | integer | Must match mode policy and human seats |
| `rank_policy` | object | Enabled flag and rank queue/category |
| `economy_policy` | object | `NONE` or named escrow policy |
| `practice_policy` | object | Bot-fill eligibility and rank/economy exclusions |
| `created_at`, `expires_at` | timestamp | Server UTC |
| `status` | enum | Contract lifecycle below |
| `contract_hash` | SHA-256 | Hash of canonical contract excluding this field/signature |

Canonical JSON uses UTF-8, lexicographically sorted object keys, no insignificant whitespace, integer numeric values only, and timestamps normalized to RFC 3339 UTC with millisecond precision. Schema implementations must publish test vectors before Package 2 exits.

Contract lifecycle:

`FORMING -> FROZEN -> RUNNING -> VERIFYING -> TERMINAL`

`FORMING` may also become `CANCELLED`. `FROZEN` content never mutates. Replacing a frozen contract requires a new `contract_id`, `match_id`, and player acceptance.

## 2. Roster v2

Roster v2 contains two to four entries, subject to mode policy. A participant's authentication and competitive identity is `player_id`, not its display snapshot.

| Field | Type | Rule |
|---|---|---|
| `player_id` | UUID/null | Required for human public participants; null only for bots |
| `public_entap_id` | string/null | Display snapshot, not authentication |
| `display_name` | string | Sanitized display snapshot |
| `participant_type` | enum | `HUMAN` or `BOT` |
| `bot_profile_id` | string/null | Required only for `BOT`; pins implementation/difficulty |
| `seat_id` | integer | Unique, contiguous, 1 through roster size |
| `team_id` | integer/null | Required for team modes; null for FFA |
| `color_id` | string | Unique where mode requires per-player color |
| `party_id` | UUID/null | Server snapshot used for 2v2 friend-pair policy |
| `rank_value` | integer/null | Server snapshot used only for initial assignment |
| `ready_state` | enum | `NOT_READY`, `READY`, `LOCKED` |
| `connection_state` | enum | `CONNECTED`, `GRACE`, `DISCONNECTED` |
| `joined_at` | timestamp | Server UTC |

Roster-level fields are `roster_version: 2`, `formed_at`, `frozen_at`, `assignment_policy_id`, and `entries`.

Validation rules:

- Human `player_id` values, seats, and required colors are unique.
- A player cannot occupy more than one seat.
- Team sizes exactly match the mode policy.
- Standard 2v2 uses `FRIEND_THEN_RANK_V1`: preserve exactly one eligible party/friend pair. With zero or multiple candidate pairs, sort by rank descending with `player_id` as deterministic tie-break; seats ranked first+fourth form one team and second+third the other.
- The client cannot choose or rewrite seat, team, party, rank snapshot, or authority tier.
- Reconnect restores the existing roster entry; it never creates a replacement identity.

### Roster-v1 compatibility

Existing host/guest fields are projections for private/internal compatibility only. A roster-v2 match may expose `host = seat 1` and `guest = seat 2` to old read paths for a two-player match, but those fields are not canonical and cannot represent 3P/4P modes. A roster-v1 client cannot join a roster-v2 public match.

## 3. Sync result v1

A sync result is immutable authority evidence. Rank and economic settlement are separate idempotent consumers; their mutable status is not part of the signed competitive outcome.

| Field | Type | Rule |
|---|---|---|
| `result_id` | UUID | Stable immutable result identity |
| `result_schema_version` | integer | `1` |
| `match_id`, `contract_id` | UUID | Must reference the frozen contract |
| `match_epoch` | integer | Must match contract |
| `contract_hash` | SHA-256 | Must match contract |
| `authority_method` | enum | `SIM_REPLAY` or `SERVER_LIFECYCLE` |
| `terminal_reason` | enum | See below |
| `placements` | array | Ordered placement groups; ties explicit |
| `winning_team_id` | integer/null | Null for no-contest or non-team winner |
| `elapsed_sim_ticks` | integer/null | Trusted simulation value |
| `final_state_hash` | SHA-256/null | Required for completed simulation replay |
| `final_command_seq` | integer | Durable high-water mark used |
| `command_log_hash` | SHA-256 | Hash of canonical ordered events |
| `sim_build_id`, `worker_build_id` | string | Exact artifacts |
| `verified_at` | timestamp | Trusted server UTC |
| `verifier_key_id` | string | Signing key identifier |
| `payload_hash`, `signature` | string | Canonical payload SHA-256 and detached signature |

Each placement group contains `place`, `player_ids`, and optional `team_id`. Every frozen human participant appears exactly once unless `terminal_reason` is `NO_CONTEST`.

Terminal reasons:

- `OBJECTIVE_COMPLETE`
- `TIME_LIMIT_PLACEMENT`
- `FORFEIT_DISCONNECT`
- `FORFEIT_VOLUNTARY`
- `NO_CONTEST`

For `NO_CONTEST`, `placements` is empty, `winning_team_id` is null, and `no_contest_reason` is required from ADR 003. A forfeit still identifies the ordered winner/loser placements.

Downstream consumer state is referenced separately by `(consumer_name, result_id, policy_version, status, side_effect_id)`. Re-verifying or redelivering a result cannot create a second rank mutation, escrow capture, payout, refund, leaderboard row, or player message.

## 4. Protocol compatibility policy

Public matching is fail-closed:

- Client `protocol_version` must equal the contract version; version 1 cannot enter roster-v2 matches.
- Client build must satisfy the published minimum and support the exact command/result schemas.
- Client and verifier must have the contract's exact `sim_build_id`, map hash, and ruleset hash.
- Unknown required fields, enum values, command versions, or hash algorithms reject start/replay.
- The server may allow additive optional response fields, but may not silently reinterpret signed or hashed fields.
- Compatibility is checked at queue entry and again before roster freeze. A config change cannot mutate an already frozen contract.

The public compatibility endpoint reports supported protocol/schema versions and minimum builds. It must not expose private service configuration.

`RELAY_ATTESTED` is limited to development, internal testing, or explicitly unranked closed beta. `AUTHORITY_VERIFIED` is required for public rank or economy. Economy permission remains a separate policy and flag; verified authority alone does not authorize settlement.

## 5. Restart and terminal ownership

ADR 003 governs restart, reconnect, forfeit, and no-contest. The match contract and result schema intentionally contain no client-authoritative terminal field. Only the durable lifecycle service and trusted verifier can advance `VERIFYING` to `TERMINAL`.
