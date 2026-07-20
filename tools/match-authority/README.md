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

The smoke launches real headless Godot twice, proves a stable terminal hash,
rejects a wrong map hash, exercises replay-disagreement no-contest, validates
trusted lifecycle forfeit/no-contest receipts, and verifies the ES256 signature.

## Runtime

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
