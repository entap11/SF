# Swarmfront Match Authority

Post-match trusted verifier for durable Standard 1v1. It leases a frozen job from
VS, verifies exact map/rules artifacts, replays the canonical command stream twice
in pinned headless Godot, and returns a detached ES256-signed sync-result-v1
receipt. Client winner/hash/time claims are never result authority.

## Local proof

```bash
npm install
npm run build
npm run smoke
```

`MATCH_AUTHORITY_HTTP_TIMEOUT_MS` bounds each worker-to-VS request and defaults
to `10000`. `MATCH_AUTHORITY_REPLAY_TIMEOUT_MS` separately bounds each Godot
replay process.

The smoke launches real headless Godot twice, proves a stable terminal hash,
rejects a wrong map hash, exercises replay-disagreement no-contest, validates
trusted lifecycle forfeit/no-contest receipts, and verifies the ES256 signature.

## Runtime

### Certified Render build

The build recipe on `main` packages the complete certified worker and simulation
from the exact commit in [`certified-release.json`](certified-release.json).
It preserves the worker/simulation IDs expected by VS. Main's newer game scripts
and worker code are not relabeled as that certified release.

Render uses these commands from the repository root:

```sh
# Build (Linux x86_64, Node >=20; git, tar, curl, unzip and Godot system libraries)
node tools/match-authority/build-certified.mjs
# Start
npm start --prefix .authority/release/tools/match-authority
```

The recipe fetches the pinned commit independently of the linked branch, verifies
the Git tree, map/rules hashes, and Godot archive/binary hashes, generates the
pinned project's class registry, imports assets, compiles the pinned worker, and
runs its real replay/signature smoke. It writes `.authority/cert-manifest.json`
and `.authority/build-receipt.json` only after those checks pass. Generated files
stay under ignored `.authority/`; the root game checkout is unchanged.

The Render environment paths remain `/opt/render/project/src/.authority/godot`
and `/opt/render/project/src/.authority/cert-manifest.json`. The manifest's
`project_path` points to `.authority/release`. A conflicting worker ID or runtime
path fails the build before replacing outputs. The dedicated GitHub workflow
rebuilds this package on Linux when the recipe or pin changes.

Changing the certified commit requires validating the new worker/simulation pair
and coordinating their IDs with VS before rollout. Source-branch housekeeping
does not change this release contract. See the
[September 29 deployment note](../../docs/authority_render_build_2026-09-29.md).

### Worker configuration

Copy `.env.example` into service-secret configuration. The private verifier key
belongs only to this worker; VS receives the matching public key. The worker token
is also dedicated to verification job operations and must never ship in Godot.

`MATCH_AUTHORITY_ARTIFACT_MANIFEST` points to JSON shaped like:

```json
{
  "worker_build_id": "authority-worker-20260718.1",
  "sim_build_id": "godot-4.2.2-swarmfront-20260718.1",
  "project_path": "/opt/swarmfront",
  "map_artifacts": { "<sha256>": "artifacts/maps/closequarters.json" },
  "ruleset_artifacts": { "<sha256>": "artifacts/rules/standard-v1.json" }
}
```

Manifest lookup alone is insufficient: the worker hashes the selected raw bytes
and rejects any mismatch before simulation. Set `MATCH_AUTHORITY_RUN_ONCE=true`
for a one-job process; otherwise it polls continuously.
`MATCH_AUTHORITY_REPLAY_TIMEOUT_MS` bounds each headless replay and defaults to
120 seconds.

`SERVER_LIFECYCLE` jobs accept one trusted `MATCH_FORFEITED` event with
`winner_player_id`, `forfeit_kind` (`DISCONNECT` or `VOLUNTARY`), and optional
`elapsed_sim_ticks`, or one `MATCH_NO_CONTEST` event with `no_contest_reason`.
Creation of disconnect-expiry events remains owned by the server lifecycle flow,
not this worker and never a player route.
