# Certified authority build from main — September 29, 2026

After branch consolidation, Render's inline authority build command still
assumed the game source and class count from `b409fc9`. Building current main
would fail the 224-class guard; simply raising it would incorrectly label a
new simulation as the old certified artifact. VS still expects the exact
`authority-worker-b409fc9` / `sf-sim-b409fc9` pair.

The build recipe now lives on `main` in
[`build-certified.mjs`](../tools/match-authority/build-certified.mjs), with an
explicit [`certified-release.json`](../tools/match-authority/certified-release.json)
pin. It builds both the worker and simulation from the certified commit in an
isolated directory. The class-count check applies to that pinned snapshot. No
gameplay, receipt-validation, signing-key, or VS contract changes are required.

## Render configuration

Service: `swarmfront-cert-authority` (`srv-d9f6j2gs116c738c7er0`).

| Setting | Value |
| --- | --- |
| Linked branch | `main` |
| Automatic deployment | Off |
| Root directory | Repository root |
| Build command | `node tools/match-authority/build-certified.mjs` |
| Start command | `npm start --prefix .authority/release/tools/match-authority` |
| Worker ID | `authority-worker-b409fc9` |
| Simulation ID | `sf-sim-b409fc9` |
| Certified source | `b409fc9797274c4a8a3cf895de7ba3d2d968197a` |
| Certified Git tree | `9e62f3b3f5f37cd926a2c393ade0bd125925bb89` |
| Engine | `4.7.1.stable.official.a13da4feb`, Linux x86_64 |

This updates future build configuration; the live deployment remains
`dep-da1j9ke417fc73ajr960`. Existing credentials, environment paths, feature
gates, and other services are preserved. An actual deployment remains a
separate release operation.

## Validation

The recipe runs with the provider's absolute filesystem paths on Linux x86_64.
It verifies the source tree and engine/content hashes, builds TypeScript, and
runs deterministic replay, map normalization, managed command lead, CTF,
lifecycle receipts, disagreement handling, invalid artifact/command rejection,
and ES256 signature checks. A manifest is published only after the smoke passes.
The independent `Certified Authority Build` GitHub workflow repeats this proof
for changes to the recipe or pin without provider credentials or live jobs.

Build output, provider before/after settings, and deployment-history checks are
retained under `SF/artifacts/authority-build-tidy-2026-09-29/`.

## Recovery

The local evidence directory preserves the previous Render build/start commands.
If a future build fails, no success manifest is produced, and the current live
deployment remains the rollback reference above. The certified source is pinned
by commit and Git tree, so it does not require restoration of an old branch.
