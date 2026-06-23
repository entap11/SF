# Money Game Ledger Contract

This is the authoritative contract for paid Swarmfront money games.

The client may preview balances and display outcomes, but paid balances, escrow, settlement, refunds, and house rake are server-authoritative. Client-local implementations are test doubles only.

## Core Rules

- All money values are integer cents.
- A money match cannot start until every player has paid the same wager into escrow.
- Escrow debit happens before match start.
- Settlement happens once, after a valid match result.
- Winner receives 90% of the escrow pot.
- House receives 10% of the escrow pot.
- Losers receive no payout.
- Every mutating ledger action requires an idempotency key.
- Repeating the same idempotency key returns the original result and must not move money again.
- A match that fails before authoritative start is refunded from escrow.
- A settled or refunded match is closed and cannot be settled or refunded again under a new key.

## Rounding

House rake is computed as:

```text
house_rake_cents = floor(pot_cents * house_rake_bps / 10000)
winner_payout_cents = pot_cents - house_rake_cents
```

Default `house_rake_bps` is `1000`, meaning 10%.

## Ledger Record

Minimum session ledger fields:

```json
{
  "session_id": "S12345678",
  "status": "escrowed",
  "player_ids": ["p1", "p2"],
  "wager_cents": 100,
  "pot_cents": 200,
  "escrow_cents": 200,
  "winner_id": "",
  "winner_payout_cents": 0,
  "house_rake_cents": 0,
  "open_idempotency_key": "open:S12345678"
}
```

Valid statuses:

- `escrowed`
- `settled`
- `refunded`

## Transaction Journal

Every successful money movement appends a posted transaction. Transaction rows are append-only, sequence-sortable, timestamped in UTC, and linked to the idempotency key that produced the posting. Repeating the same idempotency key must return the cached action result and must not append another transaction.

Minimum transaction fields:

```json
{
  "transaction_id": "SYNC-000000004",
  "transaction_seq": 4,
  "created_unix": 1783986420,
  "created_utc": "2026-07-13T16:47:00Z",
  "ledger": "sync_money_game",
  "transaction_type": "winner_payout",
  "status": "posted",
  "account_id": "p1",
  "direction": "credit",
  "amount_cents": 180,
  "balance_after_cents": 1080,
  "session_id": "S12345678",
  "player_id": "p1",
  "winner_id": "p1",
  "idempotency_key": "settle:S12345678:p1",
  "memo": "Money game winner payout"
}
```

Transaction IDs are stable opaque IDs. `transaction_seq` is the sortable numeric order within a ledger. `created_utc` is for support readouts; `created_unix` is for range filters and database sorting. Server implementations should expose filters for `account_id`, `session_id`, `contest_id`, `entry_id`, `transaction_type`, `direction`, `status`, `idempotency_key`, `from_unix`, `to_unix`, `limit`, and descending order.

Sync ledger transaction types:

- `escrow_debit`
- `winner_payout`
- `house_rake`
- `refund_credit`

Async ledger transaction types:

- `async_entry_escrow_debit`
- `async_winner_payout`
- `async_house_rake`
- `async_entry_refund_credit`

For client-local async test doubles, `balance_after_cents` is `-1` because cash balances are not held by that local contest ledger. The backend ledger should fill the real post-transaction balance whenever the payment provider/accounting system can provide it.

## Actions

### `open_money_escrow`

Debits each player and creates the escrow record.

Request:

```json
{
  "session_id": "S12345678",
  "player_ids": ["p1", "p2"],
  "wager_cents": 100,
  "idempotency_key": "open:S12345678"
}
```

Success:

```json
{
  "ok": true,
  "type": "escrow_opened",
  "session_id": "S12345678",
  "status": "escrowed",
  "player_ids": ["p1", "p2"],
  "wager_cents": 100,
  "pot_cents": 200,
  "escrow_cents": 200
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_session_id`
- `invalid_wager`
- `not_enough_players`
- `duplicate_player`
- `match_already_exists`
- `insufficient_funds`

### `open_async_entry_escrow`

Debits one async entrant and adds that entry to the contest escrow pot.

Async entries are not a two-player match start. They are contest entries whose final settlement depends on the async result authority for that contest period.

Request:

```json
{
  "entry_id": "async:WEEKLY_USD_5_2026W26:p1:12345",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "player_id": "p1",
  "wager_cents": 500,
  "idempotency_key": "open:async:WEEKLY_USD_5_2026W26:p1:12345"
}
```

Success:

```json
{
  "ok": true,
  "type": "async_entry_escrowed",
  "entry_id": "async:WEEKLY_USD_5_2026W26:p1:12345",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "player_id": "p1",
  "status": "escrowed",
  "wager_cents": 500,
  "pot_cents": 500,
  "escrow_cents": 500
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_entry_id`
- `missing_contest_id`
- `missing_player_id`
- `invalid_wager`
- `entry_already_exists`

### `settle_money_match`

Closes escrow and credits winner plus house.

For sync VS, this is triggered only after the authoritative match result is latched. In the local test double, `OpsState`/Arena produce the final owner winner and `VsHandshakeState` maps owner `1` to the session host and owner `2` to the session guest. Owner `0` means draw/no valid winner and refunds escrow instead of paying a winner.

Request:

```json
{
  "session_id": "S12345678",
  "winner_id": "p1",
  "idempotency_key": "settle:S12345678:p1"
}
```

Success:

```json
{
  "ok": true,
  "type": "match_settled",
  "session_id": "S12345678",
  "status": "settled",
  "winner_id": "p1",
  "winner_payout_cents": 180,
  "house_rake_cents": 20,
  "pot_cents": 200
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_session_id`
- `missing_winner_id`
- `match_not_found`
- `match_already_closed`
- `winner_not_in_match`
- `empty_escrow`

### `settle_async_contest`

Closes an async contest pot and credits the contest winner plus house.

Request:

```json
{
  "contest_id": "WEEKLY_USD_5_2026W26",
  "winner_id": "p1",
  "idempotency_key": "settle:WEEKLY_USD_5_2026W26:p1"
}
```

Success:

```json
{
  "ok": true,
  "type": "async_contest_settled",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "status": "settled",
  "winner_id": "p1",
  "winner_payout_cents": 900,
  "house_rake_cents": 100,
  "pot_cents": 1000
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_contest_id`
- `missing_winner_id`
- `contest_not_found`
- `contest_already_closed`
- `winner_not_in_contest`
- `empty_escrow`

### `refund_async_entry`

Refunds one escrowed async entry before contest settlement.

Request:

```json
{
  "entry_id": "async:WEEKLY_USD_5_2026W26:p1:12345",
  "reason": "failed_start",
  "idempotency_key": "refund:async:WEEKLY_USD_5_2026W26:p1:12345"
}
```

Success:

```json
{
  "ok": true,
  "type": "async_entry_refunded",
  "entry_id": "async:WEEKLY_USD_5_2026W26:p1:12345",
  "contest_id": "WEEKLY_USD_5_2026W26",
  "status": "refunded",
  "refunded_cents": 500,
  "refund_reason": "failed_start"
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_entry_id`
- `entry_not_found`
- `entry_already_closed`

### `settle_vs_money_match_result`

Client-local test-double helper for syncing a completed VS match result into the money ledger.

Request:

```json
{
  "session_id": "S12345678",
  "winner_owner_id": 1,
  "reason": "conquest"
}
```

Success:

```json
{
  "ok": true,
  "type": "match_settled",
  "session_id": "S12345678",
  "winner_owner_id": 1,
  "winner_uid": "p1",
  "winner_payout_cents": 180,
  "house_rake_cents": 20,
  "transaction_ids": ["SYNC-000000003", "SYNC-000000004"]
}
```

Draw/no-winner success:

```json
{
  "ok": true,
  "type": "match_refunded",
  "session_id": "S12345678",
  "status": "refunded",
  "refund_reason": "draw_or_no_winner",
  "transaction_ids": ["SYNC-000000003", "SYNC-000000004"]
}
```

Expected failures:

- `missing_session_id`
- `session_not_found`
- `winner_not_in_match`
- `money_match_already_refunded`

### `get_money_rematch_funding_status`

Checks whether a player can afford a paid rematch before recording a rematch vote.

Request:

```json
{
  "session_id": "S12345678",
  "owner_id": 1
}
```

Success when short:

```json
{
  "ok": true,
  "payment_required": true,
  "paid_entry": true,
  "session_id": "S12345678",
  "owner_id": 1,
  "player_uid": "p1",
  "wager_cents": 5000,
  "balance_cents": 500,
  "missing_cents": 4500
}
```

Expected failures:

- `missing_session_id`
- `session_not_found`
- `player_not_in_session`

### `prepare_money_rematch`

Creates a fresh paid rematch session and opens a new escrow before the arena resets. A paid rematch must never reuse the settled/refunded ledger record from the previous match.

Request:

```json
{
  "session_id": "S12345678"
}
```

Success:

```json
{
  "ok": true,
  "type": "money_rematch_prepared",
  "session_id": "S87654321",
  "parent_session_id": "S12345678",
  "session": {
    "id": "S87654321",
    "status": "started",
    "context": {
      "paid_entry": true,
      "wager_cents": 5000,
      "ledger_status": "escrowed",
      "rematch_parent_session_id": "S12345678",
      "rematch_index": 1
    }
  }
}
```

Expected failures:

- `missing_session_id`
- `session_not_found`
- `not_enough_players`
- `insufficient_funds`

### `refund_money_match`

Refunds escrow to all players when the match fails before authoritative start or cannot produce a valid result.

Request:

```json
{
  "session_id": "S12345678",
  "reason": "failed_start",
  "idempotency_key": "refund:S12345678"
}
```

Success:

```json
{
  "ok": true,
  "type": "match_refunded",
  "session_id": "S12345678",
  "status": "refunded",
  "refund_reason": "failed_start",
  "refunded_cents_per_player": 100
}
```

Expected failures:

- `missing_idempotency_key`
- `missing_session_id`
- `match_not_found`
- `match_already_closed`

## Required Smoke Coverage

The repository smoke tests are:

- `res://tools/money_game_ledger_smoke_test.gd`
- `res://tools/async_money_game_ledger_smoke_test.gd`
- `res://tools/vs_money_game_start_smoke_test.gd`

They must prove:

- P1/P2 enter a $1 match: each debited 100 cents, escrow becomes 200 cents.
- P1 wins: P1 receives 180 cents, house receives 20 cents, P2 receives nothing.
- Sync VS match result settlement maps winner owner to the correct escrowed session player.
- Sync VS draw/no-winner refunds escrow instead of paying a winner.
- Paid rematch vote is blocked when the local player cannot afford the next entry.
- Paid rematch opens a fresh escrow record before resetting the arena.
- Duplicate escrow open does not double debit.
- Duplicate settlement does not double pay.
- New settlement after close is rejected.
- Failed-start refund restores both players.
- Duplicate refund does not double credit.
- Insufficient funds reject before any debit.
- Missing idempotency key rejects before any debit.
- Async paid entries escrow into a contest pot.
- Async contest settlement pays 90% to the winner and 10% to the house.
- Async entry refund restores an escrowed entry before settlement.
- Every successful money movement writes a sortable posted transaction.
- Duplicate idempotency calls do not append duplicate transactions.
