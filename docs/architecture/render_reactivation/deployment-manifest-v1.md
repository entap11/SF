# Deployment Manifest v1

Status: contract frozen; one all-off certification deployment is recorded.

Recorded deployment:

- [`sf-cert-b409fc9-20260817.1`](deployment-sf-cert-b409fc9-20260817.1.json),
  linked to candidate `sf-4.7.1-b409fc9-20260817.2`. It upgrades only the
  protected, network-isolated certification estate and does not authorize or
  record production activation.

Each append-only Deployment Manifest links to exactly one approved Candidate
Release Manifest by candidate ID and digest. It records observed external state,
not intended source identity.

## Required deployment evidence

- deployment-manifest schema version, deployment record ID, timestamps, owner,
  environment classification, and linked candidate ID/digest;
- Render workspace, project, environment, service, database, worker, and deploy
  IDs where applicable;
- service type, region, plan, instance count, branch, deployed Git revision,
  provider-reported artifact/deploy identity, build/start command fingerprints,
  URLs/domain classes, health path, auto-deploy posture, and network protection;
- dependency/resource links and database/schema fingerprints without secret
  connection values;
- environment-variable names, redacted presence, and effective public/mutation
  booleans; never secret values;
- observed service versions, client compatibility, content/simulation hashes,
  remote-config revision/hash/expiry, and candidate-match result;
- health, authentication-negative, persistence, authority, restart, and
  rollback evidence with artifact locations/digests and retention;
- prior rollback deploy identity, rollback start/end/result, restored-candidate
  identity, and post-rollback data-preservation result;
- deviations, failures, quarantines, unresolved blockers, and final disposition.

## Integrity rules

- `candidate_match` is false if any deployed artifact or declared immutable
  identity differs from the linked candidate.
- A mismatch is retained as failure evidence and cannot be normalized by
  editing the Candidate Release Manifest.
- Secret values, private keys, tokens, full database URLs, unique physical
  device IDs, and player PII are prohibited.
- Later observations append a new event or deployment manifest; historical
  evidence is not rewritten.
