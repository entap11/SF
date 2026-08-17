# Candidate Release Manifest v1

Status: contract frozen. The first approved certification-only candidate is
[`sf-4.7.1-b409fc9-20260817.1`](candidate-sf-4.7.1-b409fc9-20260817.1.json),
with manifest self-digest
`4909ebd17046fafe935eadb624fc513d1fcf870b8a787265e60cbb992c296a43`.

The manifest identifies an approved deployable candidate before any external
deployment. It is canonical JSON, schema-versioned, hashed, and immutable once
approved. Dirty source trees are ineligible.

## Required identity

- manifest schema version, candidate ID, creation time, and approval state;
- repository URL, source branch, exact Git SHA, and clean-tree assertion;
- Godot engine version, distribution source, binary SHA-256, and export-template
  SHA-256;
- client build/protocol versions and minimum compatible build;
- Android application ID, version code/name, APK/AAB hashes, signing-certificate
  public fingerprint, and export preset/config hash;
- iOS bundle ID, version/build, executable/PCK/archive hashes, signing team and
  certificate/profile public identifiers, and export preset/config hash;
- VS, Rank/identity, and authority-worker artifact hashes plus build/start
  command fingerprints;
- simulation, worker, protocol, command-schema, result-schema, map, ruleset, and
  other content IDs/hashes;
- ordered database migration identities and expected schema fingerprint;
- declared all-off capability/configuration document and its hash;
- remote-operations schema/config contract hash, without a live revision ID;
- public signing-key IDs and algorithms, never private material;
- automated test suite identities, results, and retained evidence digests;
- known limitations and explicitly excluded capabilities.

## Excluded live facts

Render workspace/project/environment/resource/deploy IDs, provider URLs, live
environment values, observed health, deployment timestamps, instance IDs,
rollback deploys, database instance IDs, and live remote-config revision IDs
belong only in the linked Deployment Manifest.

## Integrity rules

- Canonical UTF-8 JSON uses sorted object keys and no insignificant whitespace.
- The manifest SHA-256 excludes only its own digest field.
- Secret values, private keys, tokens, database URLs, device IDs, and PII are
  prohibited.
- A source/artifact/config change creates a new candidate ID and manifest.
- A failed deployment never causes this manifest to be edited.
