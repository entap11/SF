# Economy Beta Certification Report — 2026-08-17

## Decision

The authoritative Platform economy foundation and zero opening epoch are
certified **GO for the read-only beta baseline**. Honey, Wax, Nectar, and
Crucible mutations remain **HOLD** behind independent default-off capability
gates until their ordered canaries pass. This report does not certify the
overall game release.

## Pinned artifacts

- Git commit: `a55a184a0cebc0a18ccdff846c9f9f39852c2b06`
- Rank deploy: `dep-da1l4p8u01pc73b16odg`
- VS deploy: `dep-da1l4pg1ne8s73ahmlfg`
- Backend archive SHA-256:
  `d9da75fa29c3677068aaeb91dcc4e6d5de9553d50f5613bee0ea106791a0aeb4`
- Rank service: `srv-d9f6j1l7vvec73foama0`
- VS service: `srv-d9f6j25aeets73ci1fjg`
- Source PostgreSQL: `dpg-d9f68vn7f7vs73c0tal0-a`
- Restore PostgreSQL: `dpg-d9f6chgs116c738bsdv0-a`

## Migration and recovery evidence

- Pre-migration custom-format backup SHA-256:
  `7c4faaad56bc1dc0dc44900c962ea1ea077c34788acb5b914cb0fcc204345053`
- Post-migration custom-format backup SHA-256:
  `199c2220616db1b9714642d0cf84236aaaf9545b3006edf02e4bd124c849372f`
- Source and restored schema SHA-256:
  `fbf55e785c6fc284ab605987b8930e4be3390dfb8eb2c0a4950e86ef4ef5f949`
- Source and restore bounded table counts matched exactly.
- Migrations `007_platform_economy.sql`,
  `008_platform_session_scopes.sql`, `009_platform_entitlements.sql`, and
  `012_platform_economy_delivery.sql` are recorded in `schema_migrations`.
- Runtime roles retain data privileges only. Schema changes were applied by the
  database owner path; app ownership was not broadened.

Five expired July certification fixtures were found in `VERIFYING` with
permanent verifier failures and no terminal results. Migration 012 closed them
as `CANCELLED` and added immutable `MATCH_VERIFICATION_FAILED` lifecycle events
with `CANCELLED_NO_ECONOMY_EFFECT`. Future permanent failures use the same
canonical lifecycle transition.

## Reset evidence

- Operator job: `job-da1l65v40ujc73bsrgig` — `succeeded`
- Epoch: `beta_launch_0001`
- Season: `BETA_S1`
- State: `ACTIVE`
- Opening Honey: `0` centi-Honey
- Opening Wax: `0` milli-Wax
- Opening Nectar: `0` milli-Nectar
- Reset audit events: `1`
- Identities preserved: `4` Rank player identities
- Legacy replay receipts preserved: `0` before and `0` after

Independent post-reset SQL verification returned:

| Invariant | Count |
| --- | ---: |
| Enabled Platform capabilities | 0 |
| Nonzero Platform accounts | 0 |
| Platform event receipts | 0 |
| Platform journal entries | 0 |
| Nonzero Nectar progressions | 0 |
| Beta entitlements | 0 |
| Nonzero Rank Wax players | 0 |
| Active VS matches | 0 |
| Open legacy Crucible escrows | 0 |
| Pending/leased/retry/failed Platform deliveries | 0 |

## Capability disposition

| Capability | State | Next gate |
| --- | --- | --- |
| Platform reads | GO | TestFlight identity/session and zero-projection canary |
| Nectar | OFF | Verified-result fact canary and reconciliation |
| Honey earn | OFF | Trusted activity-fact canary and repeat-policy vectors |
| Honey spend | OFF | Catalog/entitlement atomicity canary |
| Standard Wax | OFF | Verified-result settlement canary |
| Crucible Wax | OFF | Two-reservation/start gate, settlement, refund, and reserve reconciliation |
| Hive Honey purchase | SUPPRESSED | Trusted Hive membership/version authority contract |
| Client-local Nectar claims/awards | SUPPRESSED | Platform claim/fact contract |

The client projects authenticated Platform snapshots, uses the iOS Keychain and
Secure Enclave credential bridge, and fails closed for local Honey/Wax/Nectar
authority. The economy quarantine, proportional Hive allocation, and Battle
Pass projection smoke tests pass in Godot 4.2.

An HTTPS read canary then registered a fresh certification device/player,
issued an `economy:read` player session, read `beta_launch_0001` with Honey,
Wax, Nectar, and entitlements all zero, and revoked the session successfully.
