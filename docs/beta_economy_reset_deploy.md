# Security Sprint 0 and Beta Economy Reset Deployment

The economy epoch remains `beta_2026071301`, but Security Sprint 0 does **not** authorize applying it. Deploying a commit that contains this epoch must not reset server or local state.

## Security Sprint 0 runtime gates

Keep these values disabled on every deployment until the match-authority work and a separate reset approval are complete:

| Render service | Variable | Required Sprint 0 setting |
| --- | --- | --- |
| `sf` (service/slug `sf-zr2m`) | `VS_ECONOMY_MUTATIONS_ENABLED` | `false` |
| `sf` (service/slug `sf-zr2m`) | `VS_ECONOMY_RESET_ENABLED` | `false` |
| `entap-identity-rank-staging` | `RANK_ECONOMY_MUTATIONS_ENABLED` | `false` |
| `entap-identity-rank-staging` | `RANK_ECONOMY_RESET_ENABLED` | `false` |

The VS and rank reset paths require both their reset gate and their mutation gate. Setting only a reset gate cannot apply an epoch. The Godot project setting `swarmfront/economy/reset_enabled` also defaults to `false`. Its `SF_ECONOMY_RESET_ENABLED` development override is ignored by release exports.

## Production credential checklist

This checklist names credentials only. Never copy their values into the repository, client, logs, health responses, or support messages.

| Render service | Variable | Purpose | Sprint 0 behavior if absent |
| --- | --- | --- | --- |
| `sf` / `sf-zr2m` | `VS_MATCH_AUTHORITY_TOKEN` | Server-to-server match/economy authority | Protected authority routes fail closed; VS still starts and free PvP remains available. The future authority service must receive the identical value. |
| `sf` / `sf-zr2m` | `VS_ADMIN_TOKEN` | VS administrative writes, private ledger reads, and restricted debug fill | Protected routes fail closed; VS still starts. Configure before anyone expects those operations to work. |
| `sf` / `sf-zr2m` | `VS_SPECTATOR_ADMIN_TOKEN` | Spectator-grant creation | Grant creation fails closed. `VS_SPECTATOR_DEV_OPEN` must remain false in production. |
| `entap-identity-rank-staging` | `RANK_API_TOKEN` | Rank administrative and authoritative routes | Rank still starts when it is absent; `/health` reports authentication as not configured, and protected routes fail closed with `503 rank_auth_not_configured`. |

Other privileged server packages exist in the repository but are not declared as current Render services here:

- `tools/scholastic-service`: `SCHOLASTIC_API_TOKEN` and `SCHOLASTIC_ADMIN_TOKEN` are required if that service is deployed. Its admin token falls back to the API token when no separate admin token is configured.
- `tools/analytics`: `ADMIN_BOOTSTRAP_USERNAME` and `ADMIN_BOOTSTRAP_PASSWORD` create the dashboard/admin credential if that service is deployed. They must be overridden from repository defaults before a production deployment. `ADMIN_AUTH_REALM` is configuration, not a secret.

The public Godot/TestFlight export must keep both `swarmfront/vs/backend_token` and `swarmfront/rank/backend_token` empty. In particular, `VS_MATCH_AUTHORITY_TOKEN` is never an `SF_VS_BACKEND_TOKEN` client value.

## Storage configuration

For the current VS file adapters, `CRUCIBLE_LEDGER_STORE`, `CRUCIBLE_LEDGER_PATH`, `HONEY_LEDGER_STORE`, and `HONEY_LEDGER_PATH` identify storage but are not credentials. Production paths must point to retained storage before economy is ever enabled. Rank uses its Render-provided `DATABASE_URL`; that value is a credential and must remain private.

## Required deployment and test order

Security Sprint 0 is local-only until separately approved. When deployment is later authorized:

1. Confirm the production credential checklist without retrieving or printing any value.
2. Confirm all four server gates above are explicitly `false`, `VS_SPECTATOR_DEV_OPEN` is false, and both Godot backend-token project settings are empty.
3. Build and run the VS and rank quarantine suites locally.
4. Deploy the rank service first. Confirm `/health` reports the intended build, `economy_mutations_enabled=false`, both auth booleans true, and only the configured storage kind/path.
5. Exercise identity and read-only rank checks; do not invoke the reset.
6. Deploy the VS service. Confirm the same health properties and exercise free invite, queue, session, ready/start, heartbeat, intent, spectator, and free-bot flows.
7. Verify all economy mutation routes return HTTP 503 with `err=code=economy_disabled`, and verify private economy reads reject client/session credentials.
8. Export TestFlight only after checking that both exported backend-token settings and the reset setting remain empty/false.

## Future authority and reset order

Do not enable economy mutations merely because Sprint 0 is deployed. First deploy and validate the server-side match authority. The authority service and VS service must use the same privately configured `VS_MATCH_AUTHORITY_TOKEN`; the Godot client receives neither copy.

The beta economy reset is a separate, explicitly approved operation after authority validation. Its order is:

1. Back up and verify retained VS/rank storage.
2. Enable the reset and mutation gates only for the controlled reset window on rank, validate the epoch result, then disable the reset gate.
3. Enable the reset and mutation gates only for the controlled reset window on VS, validate Honey/Crucible state, then disable the reset gate.
4. Enable the Godot reset setting only in the specifically approved client build; never rely on the development environment override in an export.
5. Validate identities/entitlements are preserved and idempotency markers prevent a repeat on restart.

No step in this document authorizes changing the gates, applying the reset, modifying Render, or deploying without explicit approval.
