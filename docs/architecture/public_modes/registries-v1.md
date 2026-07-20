# Public Modes Registries v1

Status: Frozen for implementation
Date: 2026-07-18

Registry values are server-owned, versioned configuration. Clients may display published values but cannot define or override them.

## 1. Comparator registry

All comparators first reject unqualified, voided, incompatible, or unverified results. `qualified_at` and `player_id` are server-authored.

### `TIME_TOTAL_V1`

Applicable to timed puzzles and async map sets.

1. Require every map in the contest definition to be complete.
2. Lowest aggregate authoritative time wins. Any disclosed penalties are already included in that aggregate.
3. Earliest `qualified_at` wins.
4. Lexicographically lowest canonical `player_id` provides stable final ordering.

For best-per-player selection, apply the same ordering to that player's qualified results. Only the selected result enters the board.

### `GAUNTLET_STARS_V1`

1. Highest verified stars wins.
2. Highest completed-stage count wins.
3. Lowest elapsed simulation ticks wins.
4. Earliest `qualified_at` wins.
5. Lexicographically lowest canonical `player_id` provides stable final ordering.

Stars are derived from pinned stage thresholds in the contest definition/rules hash. The client cannot submit an authoritative star count.

Changing competitive ordering requires a new comparator ID. Existing open/closed contests keep their original comparator.

## 2. Mode policy registry

`buff_policy` values are `STANDARD`, `DISABLED`, or a future named immutable policy. Every synchronous public mode uses roster v2, command stream v1, and sync result v1 unless explicitly held.

| Mode ID | Humans | Teams | Assignment | Buffs | Result/rank | Economy | Public posture |
|---|---:|---|---|---|---|---|---|
| `STANDARD_1V1` | 2 | 1 player each | Server seats/colors | `STANDARD` | Verified Global Rank | Existing normal reward policy, separately gated | Package 5 gate |
| `CRUCIBLE_1V1` | 2 | 1 player each | Same as Standard 1v1 | `DISABLED` | No ordinary Rank award | `CRUCIBLE_WAX_V1` | Package 9 gate |
| `STANDARD_3P_FFA` | 3 | None | Unique server seats/colors | `STANDARD` | Unranked; shadow placement analytics | None | Package 11 gate |
| `STANDARD_2V2` | 4 | 2 of 2 | `FRIEND_THEN_RANK_V1` | `STANDARD` | Unranked; shadow team analytics | None | Package 11 gate |
| `STANDARD_4P_FFA` | 4 | None | Unique server seats/colors | `STANDARD` | Unranked; shadow placement analytics | None | Package 11 gate |
| `CTF_1V1` | 2 | 1 player each | Server seats/colors | Ruleset-defined | Unranked for initial public proof | None | Package 6 gate |
| `HCTF_1V1` | 2 | 1 player each | Server seats/colors | Ruleset-defined | Not authorized yet | None | `HOLD` for live secrecy |
| `CTF_BOT` | 1 + bot | 1 player each | Server seat plus pinned bot | Ruleset-defined | Practice only; no public rank | None | Package 6 practice gate |
| `HCTF_BOT` | 1 + bot | 1 player each | Server seat plus pinned bot | Ruleset-defined | Practice only; no public rank | None | Package 6 practice gate |

Bot diversion is offered only after a server-configured human CTF/HCTF search threshold. It requires explicit player acceptance, creates a new practice contract, and never silently converts a ranked human queue into a bot result. HCTF bot play may proceed locally/practice because no human opponent receives hidden state; it still cannot imply that human HCTF is public-ready.

`FRIEND_THEN_RANK_V1` means:

- Exactly one server-verified friend/party pair: keep that pair together; the other two form the opposing team.
- Zero or multiple candidate pairs: sort by rank descending, then player UUID ascending; highest+lowest play together against the two middle players.

`CRUCIBLE_WAX_V1` means exact integer milli-Wax accounting:

- Reserve `1000 wax_millis` from each participant before start.
- Total escrow is `2000 wax_millis`.
- Verified winner receives `1800 wax_millis`.
- `200 wax_millis` moves to a separately audited award-pot account.
- No-contest refunds `1000 wax_millis` to each participant.
- Open, settle, pot transfer, and refund are atomic/idempotent ledger operations. Floating point is forbidden.

The named pot is custody, not an automatic player reward. Awarding it requires a separate administrative/reward policy and audit path; Package 0 does not authorize an award action.

### Disconnect policy

All human synchronous modes use `SYNC_RECONNECT_V1`:

- VS records disconnect and a server-time grace deadline durably.
- A reconnecting authenticated player resumes the same seat and epoch.
- Process restart does not extend the deadline.
- If grace expires, server lifecycle records a forfeit for trusted verification.
- If lifecycle/stream evidence is incomplete, the outcome is no-contest under ADR 003.

The grace duration is server-published operational configuration and may differ by mode without changing schema or authority. Bots do not replace a disconnected human mid-match.

### Reward policy

- Standard 1v1 may consume the existing approved normal reward policy only after verified authority and the independent mutation flag are enabled.
- Crucible consumes only `CRUCIBLE_WAX_V1` and never ordinary Rank settlement.
- 3P FFA, 2v2, 4P FFA, initial Human CTF, and bot practice have no reward.
- Time, Gauntlet, and free async v1 produce placement/results only. No reward schedule is authorized.

## 3. Contest policy registry

| Policy ID | Family/scope | Maps | Attempts | Comparator | Close rule | Public posture |
|---|---|---:|---|---|---|---|
| `TIME_WEEKLY_V1` | Time/weekly | 3 or 5 | Unlimited; best/player | `TIME_TOTAL_V1` | Server UTC period | Package 8 gate |
| `TIME_MONTHLY_V1` | Time/monthly | 3 or 5 | Unlimited; best/player | `TIME_TOTAL_V1` | Server UTC period | Package 8 gate |
| `TIME_SEASONAL_V1` | Time/seasonal | 3 or 5 | Unlimited; best/player | `TIME_TOTAL_V1` | Explicit season boundary | Package 8 gate |
| `GAUNTLET_WEEKLY_V1` | Gauntlet/weekly | Definition sequence | Unlimited; best/player | `GAUNTLET_STARS_V1` | Server UTC period | Package 8 gate |
| `ASYNC_3_ROLLING_4P_V1` | Async/rolling | 3 | One scored/player/cohort | `TIME_TOTAL_V1` | Four distinct qualified players | Package 10 gate |
| `ASYNC_5_ROLLING_4P_V1` | Async/rolling | 5 | One scored/player/cohort | `TIME_TOTAL_V1` | Four distinct qualified players | Package 10 gate |

Period boards display only the best qualified result for each player. Free rolling async boards contain exactly one qualified result for each of four distinct players and message final top-three placement.

Canonical scope values are `WEEKLY`, `MONTHLY`, and `SEASONAL`. Existing `YEARLY` input is accepted only by migration/import code as an alias for `SEASONAL`; new persisted/public contracts never emit `YEARLY`.

## 4. Idempotency namespace registry

Every mutation has a caller-generated or producer-stable idempotency key. Keys are scoped by namespace and authoritative subject; the same raw key in another namespace is unrelated. Stored records include request hash, response/side-effect reference, status, and timestamps. Same key plus different canonical request is `idempotency_conflict`.

| Namespace | Uniqueness scope | Stable producer key/example |
|---|---|---|
| `identity.register.v1` | Device public-key fingerprint + request ID | Registration request ID |
| `identity.session.v1` | Device ID + nonce ID | Challenge nonce |
| `match.queue.v1` | Player + mode + request ID | Client queue request ID |
| `match.command.v1` | Match + epoch + client command ID | Client UUID |
| `match.lifecycle.v1` | Match + epoch + lifecycle event ID | Server event UUID |
| `match.verify.v1` | Match + epoch | Verification subject |
| `match.result.v1` | Result ID | Signed verifier result ID |
| `rank.sync_result.v1` | Result ID + rank policy | Verifier result ID |
| `contest.attempt.v1` | Contest + player + request ID | Client request ID |
| `contest.result.v1` | Contest + attempt + submission ID | Attempt-bound UUID |
| `contest.close.v1` | Contest ID + definition hash | Contest ID |
| `contest.message.v1` | Contest + recipient + message kind | Server-derived message ID |
| `outbox.delivery.v1` | Consumer + event ID | Outbox event ID |
| `crucible.reserve.v1` | Match + player | Contract ID + player ID |
| `crucible.settle.v1` | Verified result ID | Result ID |
| `crucible.refund.v1` | Match + player + no-contest result | Result ID + player ID |
| `crucible.pot.v1` | Verified result ID | Result ID |

Client retries must reuse keys after timeout. Services retain terminal idempotency records at least as long as the corresponding result/economic audit evidence.

## 5. Protocol registry

| Contract | Frozen version | Initial consumer |
|---|---:|---|
| Player token | 1 | Identity, VS |
| Public match/roster | 2 | VS, Godot, verifier |
| Command stream | 1 | VS, Godot, verifier |
| Sync result | 1 | Verifier, VS, rank, ledger |
| Public contest | 1 | VS/contest service, Godot |
| Comparator registry | 1 | Contest service, dashboard |

Versions are explicit in payloads and persisted records. A service must reject an unsupported required version rather than falling back to a legacy parser.

## 6. Release flags

Package 0 does not create or enable flags. Target flags must default false in source and remote configuration, and must be independently reversible by mode/package. No UI visibility flag may bypass identity, verifier, economy, or lifecycle gates.
