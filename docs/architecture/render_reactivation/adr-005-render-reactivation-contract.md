# ADR 005 — Render Reactivation Contract

Status: Accepted for discovery and integration assessment
Date: 2026-08-12

## Context

Swarmfront has a complete default-off Public Modes implementation and a
previously certified Render topology, while its current phone-facing service is
a narrower private relay. Reactivating the complete Render platform must not be
confused with enabling public play or economic effects.

## Decision

Render reactivation is an infrastructure restoration and certification
program. It is not a feature-development or launch-authorization program.

The target for this program is the minimum complete, all-off topology capable
of authenticated clients, durable state, trusted result verification, remote
operations, evidence collection, and tested rollback. Whether existing Render
resources can reach that target through reuse, reconfiguration, or upgrade is
decided from discovery evidence; a replacement Production environment is not
assumed.

The following constraints are frozen:

1. Non-economic Standard 1v1 remains the first eventual public candidate.
   Public activation is outside the current authorization.
2. `OpsState`/`SimState` remain the only gameplay-state mutation authority.
3. A trusted worker derives public results by running the same certified
   Godot/simulation revision as the clients.
4. Certification and Production remain distinct environments.
5. Every public, Rank, Honey, Wax, Crucible, contest, reward, leaderboard,
   settlement, and other mutation capability defaults false and remains false
   throughout reactivation certification.
6. PostgreSQL or an explicitly accepted canonical durable store is required for
   public/economic state. Memory and file adapters are development/private
   compatibility stores and cannot silently become authority.
7. Human HCTF remains excluded until hidden state is architecturally protected
   from opposing clients, packets, logs, replays, snapshots, and predictable
   seeds.
8. Economic async contests remain excluded.
9. Canonical production ownership of Honey and Wax must be resolved before any
   economy-production implementation or activation. No such resolution is
   invented by this ADR.
10. Every deployable candidate is identified by a Candidate Release Manifest
    that exists before deployment.
11. Each actual deployment is identified by a separate Deployment Manifest
    linked to exactly one Candidate Release Manifest. Provider service/deploy
    IDs and other live facts never appear as candidate identity.
12. Every changed Render component requires an observed rollback before any
    activation decision.
13. Tests, thresholds, gameplay/economy rules, and certification gates are not
    weakened to manufacture a pass. Original failure evidence is retained
    before a fix or rerun.

## Manifest boundary

The Candidate Release Manifest answers **what was approved to deploy**. It is
immutable before the first external deployment and contains source, build,
client, simulation, content, schema, and declared configuration identity.

The linked Deployment Manifest answers **what was actually deployed where**.
It is append-only evidence containing Render resource/deploy identities,
observed effective configuration, health, timing, and rollback results.

One candidate can have multiple deployment manifests. A deployment manifest
cannot point to multiple candidates, and a deployed artifact mismatch creates
a failed deployment record rather than silently revising the candidate.

## Authority boundary

VS may authenticate players, freeze contracts/rosters, durably order commands,
and own lifecycle deadlines. It does not mutate gameplay state or accept a
client-selected winner. The authority worker replays the canonical stream
through `OpsState`/`SimState` and signs the result. Rank, contest, Honey, Wax,
and settlement consumers require their own authorization, idempotency, and kill
switches; a verified result does not by itself authorize a side effect.

## Consequences

- Reactivation can finish with every feature still unavailable to players.
- Discovery may recommend reuse, reconfiguration, upgrade, clone/migration, or
  replacement, in that preference order.
- Unresolved Honey/Wax ownership is recorded as a later blocker, not filled by
  adopting whichever legacy store happens to exist.
- Deployment, migration, secret rotation, plan changes, and enablement require
  a later explicit authorization.
