# Read-Only Render Estate Inventory

- Observed: 2026-08-12
- Provider workspace: Render
- Project: `My project` (`prj-d7uho167r5hc73b4euh0`)
- Method: Render CLI 2.22.0 list/get operations, Render API `GET` for
  environment-variable names and custom domains, public health `GET`, and
  bounded read-only PostgreSQL queries
- Mutations performed: none
- Secret values recorded: none

`OBSERVED` means directly read on 2026-08-12. `REPOSITORY` means derived from
the checked-out source. `HISTORICAL` means retained certification evidence.
`INFERRED` is an explicitly labeled conclusion. `UNKNOWN` remains unresolved.

## Environment and resource inventory

### Certification — `OBSERVED`

Environment `evm-d9f68mos116c738bmf60` is protected and network-isolated.

| Resource | Provider ID | Current state | Live deploy/revision | Treatment |
| --- | --- | --- | --- | --- |
| `swarmfront-cert-vs` | `srv-d9f6j25aeets73ci1fjg` | Starter Node web service, Oregon, one instance, auto-deploy off, healthy | `dep-d9t2nfad0e5s738kkg6g` / `08c2066c2f200904cac66a8b693ef7ea719b2f22` | `REUSE` + `UPGRADE`; bind a clean 4.7.1 candidate and rerun all-off certification. |
| `swarmfront-cert-rank` | `srv-d9f6j1l7vvec73foama0` | Starter Node web service, Oregon, one instance, auto-deploy off, healthy | `dep-d9f9qhbrjlhs739srt10` / `60bef51e6a2e10fe60be05017053f8550df143c0` | `REUSE` + `UPGRADE`; retain identity and fail-closed mutation boundaries. |
| `swarmfront-cert-authority` | `srv-d9f6j2gs116c738c7er0` | Starter Node worker, Oregon, one instance, auto-deploy off | `dep-d9fahjreo5us73e50fj0` / `60bef51e6a2e10fe60be05017053f8550df143c0` | `REUSE` + `UPGRADE`; its build is explicitly pinned to Godot 4.2.2 and old sim/worker IDs. |
| `swarmfront-cert-db` | `dpg-d9f68vn7f7vs73c0tal0-a` | PostgreSQL 18.4, Basic 256 MB, 1 GB, available, no HA | not applicable | `REUSE`; current certification source. No migration was run. |
| `swarmfront-cert-db-restore` | `dpg-d9f6chgs116c738bsdv0-a` | PostgreSQL 18.4, Basic 256 MB, 1 GB, available, no HA | not applicable | `REUSE`; isolated recovery target. No restart or restore was run. |

The services remain on branch `deploy/staging-cert-20260720`. VS and Rank use
their service directories; the authority worker builds from the repository
root. No service has a custom domain.

### Production — `OBSERVED`

Environment `evm-d7uho167r5hc73b4euhg` is unprotected and is not
network-isolated.

| Resource | Provider ID | Current state | Live deploy/revision | Treatment |
| --- | --- | --- | --- | --- |
| `SF` | `srv-d7uho16gvqtc73feh9s0` | Free Node web service, Oregon, one instance, auto-deploy off, healthy | `dep-d9trj3ht0dsc73bvmf9g` / `36614cc5ac93587e12dd870935d1fef6e584ae71` | `REUSE` as the current private VS and rollback anchor; `RECONFIGURE`/`UPGRADE` before it can participate in the complete target topology. |

No production PostgreSQL, Rank/identity service, authority worker, or custom
domain is attached to this environment. The absence is an observed inventory
fact, not authorization to create replacements.

### Unassigned legacy Rank pair — `OBSERVED`

| Resource | Provider ID | Current state | Live deploy/revision | Treatment |
| --- | --- | --- | --- | --- |
| `entap-identity-rank-staging` | `srv-d8uqramrnols73fjl820` | Starter Node web service, Oregon, auto-deploy off, healthy; verified custom domain `rank-api.entap.games` | `dep-d9akqmlaeets73bp7n6g` / `73fbc032a6c0edb03908d6deb0f50ca10882621b` | `REUSE` candidate, subject to ownership, security placement, schema, identity-data, and rollback review. Do not silently treat staging as production. |
| `entap-identity-rank-staging-db` | `dpg-d8uqqq6rnols73fjkoag-a` | PostgreSQL 18.4, Basic 256 MB, 15 GB, available, no HA | not applicable | `REUSE` or `MIGRATE` decision required after data/ownership review. It is not attached to the Production project environment. |

## Health and effective capability posture — `OBSERVED`

All three web health probes returned HTTP 200.

| Capability | Certification VS | Production `SF` |
| --- | --- | --- |
| Deployed build | `08c2066` | `36614cc` |
| Economy mutations | off | off |
| Public modes, contests, rewards, rank mutations | all off | all off |
| Administrative auth required | yes | no |
| Player auth configured | yes | no |
| Durable VS core | PostgreSQL, configured | memory, not configured |
| Durable public 1v1 repository | enabled | disabled |
| Match verification | enabled | disabled |
| Remote operations config | enabled, 60-second reconciliation | disabled |
| Public contest store authorized | yes | no |
| Honey store | file | file |
| Crucible store | file | file |
| General money store | memory | memory |

Certification Rank reports PostgreSQL storage, service authentication,
verifier receipt authentication, administrative/match-authority auth, and
player identity sessions configured. Economy, verified-match, and public
leaderboard mutations are off. The legacy Rank health endpoint reports only
that the service and database are healthy; it does not prove the newer trust
boundaries.

The file and memory Honey/Wax-adjacent implementations are not accepted as
authoritative production ownership. Their presence confirms the ownership
matrix blocker.

## Environment-variable names — `OBSERVED`

Values were neither requested nor recorded. Names establish configured seams,
not correctness.

### Certification authority

`MATCH_AUTHORITY_ARTIFACT_MANIFEST`, `MATCH_AUTHORITY_GODOT_BIN`,
`MATCH_AUTHORITY_POLL_MS`, `MATCH_AUTHORITY_REPLAY_TIMEOUT_MS`,
`MATCH_AUTHORITY_RUN_ONCE`, `MATCH_AUTHORITY_VERIFIER_KEY_ID`,
`MATCH_AUTHORITY_VERIFIER_PRIVATE_KEY_PEM`,
`MATCH_AUTHORITY_WORKER_BUILD_ID`, `MATCH_AUTHORITY_WORKER_ID`, `NODE_ENV`,
`VS_BASE_URL`, `VS_VERIFIER_WORKER_TOKEN`.

### Certification Rank

`BIND_HOST`, `DATABASE_URL`, `ENTAP_PLAYER_TOKEN_AUDIENCE`,
`ENTAP_PLAYER_TOKEN_ISSUER`, `ENTAP_PLAYER_TOKEN_KEY_ID`,
`ENTAP_PLAYER_TOKEN_PRIVATE_KEY_PEM`, `ENTAP_PLAYER_TOKEN_PUBLIC_KEY_PEM`,
`NODE_ENV`, `RANK_API_TOKEN`, `RANK_ECONOMY_MUTATIONS_ENABLED`,
`RANK_ECONOMY_RESET_ENABLED`, `RANK_ENABLE_DEBUG_ACTIONS`,
`RANK_ENFORCE_CANONICAL_PLAYER_IDS`, `RANK_PUBLIC_LEADERBOARDS_ENABLED`,
`RANK_SERVICE_TOKEN_AUDIENCE`, `RANK_SERVICE_TOKEN_ISSUER`,
`RANK_SERVICE_TOKEN_KEY_ID`, `RANK_SERVICE_TOKEN_PUBLIC_KEY_PEM`,
`RANK_SERVICE_TOKEN_SUBJECT`, `RANK_VERIFIED_MATCH_MUTATIONS_ENABLED`,
`RANK_VERIFIER_KEY_ID`, `RANK_VERIFIER_PUBLIC_KEY_PEM`,
`RANK_VERIFIER_RECEIPT_MAX_AGE_SEC`, `RANK_VERIFIER_WORKER_BUILD_ID`.

### Certification VS

`BIND_HOST`, `NODE_ENV`, `VS_ADMIN_TOKEN`,
`VS_AUTHENTICATED_1V1_SLICE_ENABLED`, `VS_CORS_ENABLED`, `VS_DATABASE_URL`,
`VS_DURABLE_CORE_ENABLED`, `VS_DURABLE_PUBLIC_1V1_ENABLED`,
`VS_DURABLE_STORE`, `VS_ECONOMY_MUTATIONS_ENABLED`,
`VS_ECONOMY_RESET_ENABLED`, `VS_ENABLE_CONTEST_REWARDS`,
`VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT`, `VS_ENABLE_CTF_BOT_FALLBACK`,
`VS_ENABLE_PUBLIC_1V1`, `VS_ENABLE_PUBLIC_2V2`, `VS_ENABLE_PUBLIC_3P_FFA`,
`VS_ENABLE_PUBLIC_4P_FFA`, `VS_ENABLE_PUBLIC_ASYNC_3MAP`,
`VS_ENABLE_PUBLIC_ASYNC_5MAP`, `VS_ENABLE_PUBLIC_CONTESTS`,
`VS_ENABLE_PUBLIC_CRUCIBLE`, `VS_ENABLE_PUBLIC_CTF`,
`VS_ENABLE_PUBLIC_GAUNTLET`, `VS_ENABLE_PUBLIC_HCTF`,
`VS_ENABLE_PUBLIC_LEADERBOARDS`, `VS_ENABLE_PUBLIC_TIME_PUZZLES`,
`VS_ENABLE_RANK_MUTATIONS`, `VS_ENABLE_REMOTE_OPS_CONFIG`,
`VS_HCTF_LIVE_SECRECY_CERTIFIED`, `VS_MATCH_AUTHORITY_TOKEN`,
`VS_MATCH_VERIFICATION_ENABLED`, `VS_OPS_RECONCILE_INTERVAL_MS`,
`VS_PLAYER_TOKEN_AUDIENCE`, `VS_PLAYER_TOKEN_ISSUER`,
`VS_PLAYER_TOKEN_KEY_ID`, `VS_PLAYER_TOKEN_PUBLIC_KEY_PEM`,
`VS_PRODUCTION_MODE`, `VS_PUBLIC_1V1_AUTHORITY_TIER`,
`VS_PUBLIC_1V1_MAP_HASH`, `VS_PUBLIC_1V1_MAP_ID`,
`VS_PUBLIC_1V1_MINIMUM_CLIENT_BUILD`, `VS_PUBLIC_1V1_RULESET_HASH`,
`VS_PUBLIC_1V1_RULESET_ID`, `VS_PUBLIC_1V1_SIM_BUILD_ID`,
`VS_PUBLIC_CONTEST_GRANT_SECRET`, `VS_RANK_SERVICE_TOKEN_AUDIENCE`,
`VS_RANK_SERVICE_TOKEN_ISSUER`, `VS_RANK_SERVICE_TOKEN_KEY_ID`,
`VS_RANK_SERVICE_TOKEN_PRIVATE_KEY_PEM`, `VS_RANK_SERVICE_TOKEN_SUBJECT`,
`VS_RANK_SERVICE_URL`, `VS_SPECTATOR_ADMIN_TOKEN`,
`VS_SPECTATOR_DEV_OPEN`, `VS_SPECTATOR_ENABLED`,
`VS_SPECTATOR_LIVE_ENABLED`, `VS_SPECTATOR_PUBLIC_ENABLED`,
`VS_VERIFIER_KEY_ID`, `VS_VERIFIER_LEASE_SEC`,
`VS_VERIFIER_PUBLIC_KEY_PEM`, `VS_VERIFIER_WORKER_BUILD_ID`,
`VS_VERIFIER_WORKER_TOKEN`.

### Production and legacy Rank

Production `SF` has only `VS_MATCH_AUTHORITY_TOKEN`. Legacy Rank has
`BIND_HOST`, `DATABASE_URL`, `RANK_API_TOKEN`, `RANK_DEFAULT_REGION`,
`RANK_ECONOMY_EPOCH`, `RANK_ENABLE_DEBUG_ACTIONS`, and
`RANK_ENFORCE_CANONICAL_PLAYER_IDS`.

## Bounded database state — `OBSERVED`

No migration or write query was executed.

| Database | Public base tables | Migration rows | Schema SHA-256 |
| --- | ---: | ---: | --- |
| Certification source | 47 | 17 | `e8cdc990973c29dee564ef4b6756ada0b6c4034cc7d3f6a5a2a4f502b56478c3` |
| Certification restore | 47 | 17 | `e8cdc990973c29dee564ef4b6756ada0b6c4034cc7d3f6a5a2a4f502b56478c3` |
| Legacy Rank | 5 | 4 | `3c300c32b12f0ea28898f6a4f0ee5ac68b34505bf2edc6196ff2ec9184dbc8fe` |

The certification databases contain the repository's 11 VS and 6 Rank
migration filenames through `011_public_modes_operations.sql` and
`006_public_contest_scope.sql`. The legacy Rank database stops at
`004_identity_beta_constraints.sql`; it lacks device sessions and public
contest scope.

## Observed rollback anchors

These are provider history facts, not a recommendation to roll back blindly.
Any later rollback must name an exact tested deploy in the Deployment Manifest.

| Resource | Current live | Immediate prior deactivated deploy |
| --- | --- | --- |
| Certification VS | `dep-d9t2nfad0e5s738kkg6g` / `08c2066` | `dep-d9fafrjtqb8s73club1g` / `60bef51` |
| Certification Rank | `dep-d9f9qhbrjlhs739srt10` / `60bef51` | `dep-d9f9d8vavr4c73b8t4ug` / `9159648` |
| Certification authority | `dep-d9fahjreo5us73e50fj0` / `60bef51` | `dep-d9fa2treo5us73836h9g` / `60bef51`; earlier distinct revision `9159648` |
| Production `SF` | `dep-d9trj3ht0dsc73bvmf9g` / `36614cc` | `dep-d9tqqjvavr4c73cfq8pg` / `5b5ffc0` |
| Legacy Rank | `dep-d9akqmlaeets73bp7n6g` / `73fbc03` | `dep-d8uqrb6rnols73fjl8u0` / `2c9d8c2` |

## Current-to-target delta

The minimum target remains a separate certification and production topology,
each binding the same certified client/sim/worker identity, with all public and
economy capabilities off until separately authorized.

| Requirement | Certification | Production | Delta |
| --- | --- | --- | --- |
| Isolated/protected environment | present | absent | Decide and authorize the least disruptive protection/placement change. |
| VS service | present | present | Both require exact candidate binding; production requires durable/auth/verifier configuration. |
| Rank/identity | present | not attached | Determine whether the legacy pair can be safely reused/migrated or a distinct production instance is unavoidable. |
| Managed PostgreSQL | source + restore present | not attached | Resolve production database reuse/migration and data ownership; no new database is assumed. |
| Separate authority worker | present, 4.2.2 | absent | Certification must upgrade; production needs a separate worker unless discovery finds an existing one. None was found. |
| Exact 4.7.1 sim/worker identity | absent | absent | Build and certify one candidate, then link each deployment manifest to it. |
| Honey/Wax durable canonical ownership | unresolved | unresolved | Architecture decision required; file/memory stores cannot fill the gap. |
| Rollback declaration | history exists | history exists for VS only | Select exact deploy and database recovery points before any activation. |

## Estate conclusion

`INFERRED`: the protected certification topology should be reused in place.
There is no evidence supporting replacement.

`INFERRED`: production can retain the existing `SF` service as the private VS
and rollback anchor, but the complete production topology cannot be declared
until the legacy Rank/database reuse decision, environment protection,
separate authority, and canonical Honey/Wax ownership are resolved. Discovery
does not justify creating a parallel “Prod v2,” nor does it justify pretending
the single legacy service is the complete stack.
