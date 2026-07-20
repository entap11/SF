# ENTaP Identity / Rank Service

First ENTaP platform identity authority, currently hosted in the historical `tools/rank-service` package. For Swarmfront beta, the required production surface is identity creation only; rank features can remain dormant.

## Why this exists

This service is separate from analytics and the VS backend. The game points `SF_RANK_BACKEND_URL` here so account creation can receive server-assigned UUIDv7 internal IDs and public ENTaP IDs.

## API shape

- Beta identity route: `POST /v1/rank/register_player`
- Device-backed registration: `POST /v1/identity/register`
- Device challenge: `POST /v1/identity/challenge`
- Player session issuance: `POST /v1/identity/session`
- Current-session revocation: `POST /v1/identity/session/revoke`
- Player-token JWKS: `GET /.well-known/jwks.json`
- General route shape: `POST /v1/rank/<action>`
- Verified Standard 1v1 settlement: `POST /v1/service/settle-standard-1v1` (VS service JWT only)
- Public Global Rank: `GET /v1/public/leaderboard/global` (independently gated)
- Matches `/Users/home/SideProjects/SF/project/docs/rank_backend_contract.md`
- Responses use `{ "ok": true, ... }` / `{ "ok": false, "err": "..." }`

## Setup

```bash
cd tools/rank-service
cp .env.example .env
docker compose up -d
npm install
npm run dev
npm run smoke:quarantine
```

Migrations also run automatically on service startup. You can run them manually with:

```bash
npm run migrate
```

Default server: `http://127.0.0.1:8790`

From project root, you can also start rank service + Godot together:

```bash
./tools/run_with_rank_service.sh
```

If your Postgres is not on the default local URL, set it before launch:

```bash
RANK_DATABASE_URL=postgres://user:pass@host:5432/swarmfront_rank ./tools/run_with_rank_service.sh
```

Identity-only smoke against a real Postgres URL:

```bash
RANK_DATABASE_URL=postgres://user:pass@host:5432/swarmfront_rank ./tools/run_rank_identity_smoke.sh
```

## Beta identity contract

- Client sends `call_sign`, `region`, and optional `install_metadata`.
- Client does not send an authoritative account ID during beta account creation.
- Service assigns UUIDv7 `id`.
- Service assigns sequential public `entap_id` using `rank_entap_id_seq`.
- Duplicate call signs return `409` with `err=call_sign_not_unique`.
- Canonical rank IDs are UUIDv7 for human players and `bot_<6 digits>` for bot seats.
- Debug rank mutation endpoints are disabled by default.
- Admin/ops routes are available under `/v1/admin/*` and use the same bearer token gate as gameplay routes when `RANK_API_TOKEN` is set.

## Device-backed player sessions

Package 1 adds a separate player credential path without changing the legacy beta registration route:

1. A device creates a non-exportable ECDSA P-256 key and sends only its public JWK to `/v1/identity/register` with a stable request ID.
2. The service atomically creates the UUIDv7 player, registered device, and single-use challenge.
3. The device signs the returned challenge with ECDSA/SHA-256 and submits the base64url signature to `/v1/identity/session`.
4. The service returns a ten-minute ES256 player JWT scoped to `match:queue`
   and `contest:play`; neither scope grants rank/economy/service mutation.

The player JWT is distinct from `RANK_API_TOKEN`. It cannot authorize rank mutation, admin, or service operations. Private device keys never reach this service.

Configure an ES256 issuer key pair through `ENTAP_PLAYER_TOKEN_PRIVATE_KEY_PEM` and `ENTAP_PLAYER_TOKEN_PUBLIC_KEY_PEM`. Both endpoints fail closed with HTTP 503 when keys are absent. PEM environment values may contain real newlines or escaped `\\n` newlines. Generate a staging pair outside the repository, store the private key only in service secret storage, and copy only the public key to VS.

Useful checks:

```bash
npm run build
npm run smoke:player-token
RANK_ECONOMY_MUTATIONS_ENABLED=true npm run smoke:verified-settlement
RANK_SMOKE_BASE_URL=http://127.0.0.1:8790/v1/rank npm run smoke:session
```

`smoke:session` requires a running migrated rank service configured with the player-token key pair.

## Wire Godot client

Set environment (or project setting) so rank transport points to this service:

```bash
SF_RANK_BACKEND_URL=http://127.0.0.1:8790/v1/rank
# Do not ship RANK_API_TOKEN in a public client. The new player-session flow supplies
# a short-lived player token to authenticated player routes instead.
```

For staging/production beta builds, configure the deployed Render URL instead of the local URL.

## Render staging deployment

The repo root includes `render.yaml` for a separate staging web service and Postgres database:

- Web service: `entap-identity-rank-staging`
- Database: `entap-identity-rank-staging-db`
- Root directory: `tools/rank-service`
- Build command: `npm ci && npm run build`
- Start command: `npm run start`
- Health check: `/health`
- `RANK_ECONOMY_MUTATIONS_ENABLED=false` quarantines Wax/result/decay/debug economy writes and is the production default.
- `RANK_ECONOMY_RESET_ENABLED=false` is a separate reset gate. The `RANK_ECONOMY_EPOCH=beta_2026071301` marker cannot reset anything unless both gates are explicitly enabled.

After deployment, set a real `RANK_API_TOKEN`, run migrations if needed, then smoke:

```bash
RANK_SMOKE_BASE_URL=https://YOUR-RANK-STAGING.onrender.com/v1/rank \
RANK_SMOKE_TOKEN=$RANK_API_TOKEN \
SF_ALLOW_LIVE_BACKEND_TESTS=1 \
npm run smoke:identity
```

## Persistence

- Source of truth is Postgres (`DATABASE_URL`).
- `RANK_STATE_PATH` is legacy import only. If a JSON state file exists and DB is empty, service imports it once on startup.
- Every state transaction is classified at the store boundary as `identity` or `economy`; an unclassified write is rejected. Identity writes are structurally prevented from changing Wax, decay inputs, rank-derived fields, processed events, or economy audit records.
- Identity registration is the sole quarantine exception: it may create an identity, exactly zero Wax, and one `player_registered` audit event. It cannot grant starting Wax while economy mutations are disabled.
- Client-local Rank/Wax simulation is available only when both a Godot debug build and `enable_rank_local_beta_fallback` are active. Production exports ignore that flag.

## Real-time guarantees

- Rank writes are synchronous DB transactions.
- Match result applies wax + recomputes tier/color/rank immediately.
- Response is returned only after commit, so a player crossing a tier threshold is promoted as they exit that match.
- Demotion smoothing defaults to 5 pass-through slots (`RANK_TIER_DEMOTION_GRACE_SLOTS=5`), and overflow in a full tier is pushed upward by promoting the top edge into the next tier.

## Verified Standard 1v1 settlement

- `RANK_VERIFIED_MATCH_MUTATIONS_ENABLED=false` is the dedicated verified-result consumer gate; the existing `RANK_ECONOMY_MUTATIONS_ENABLED` gate must also be true before a rank write can occur.
- VS authenticates with a short-lived ES256 JWT whose issuer, audience, subject, key ID, public key, scope, and lifetime are checked exactly. Configure the accepted identity with `RANK_SERVICE_TOKEN_*`; the private key remains in VS secret storage.
- Rank independently verifies the detached ES256 match-authority receipt using `RANK_VERIFIER_KEY_ID`, `RANK_VERIFIER_PUBLIC_KEY_PEM`, `RANK_VERIFIER_WORKER_BUILD_ID`, and the bounded `RANK_VERIFIER_RECEIPT_MAX_AGE_SEC` before applying a result.
- `rank_event_id` is the immutable verifier `result_id`. The processed-event ledger makes retries and post-restart delivery idempotent.
- `RANK_PUBLIC_LEADERBOARDS_ENABLED=false` independently gates the shared Global Rank read. The endpoint labels its generation time and cache age and has no device-local fallback.
- Run `npm run smoke:verified-settlement` for embedded-PostgreSQL service-token, receipt-signature, durable dedupe, and audit evidence.

## Admin endpoints

- `GET /health/details`
- `GET /v1/admin/players/:playerId`
- `GET /v1/admin/tier-counts`
- `GET /v1/admin/audit`
- `POST /v1/admin/recompute`

## Beta simulation

Run a repeatable ladder simulation without needing a live DB:

```bash
cd tools/rank-service
npm run simulate:beta -- --players=600 --matches=3000 --seed=1337
```

This prints a JSON summary of tier distribution, color distribution, and top players so you can sanity check unlock/open-tier behavior before putting real testers on the service.
