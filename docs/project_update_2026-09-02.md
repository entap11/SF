# Project Update — September 2, 2026

Status: current cross-workstream rollup

Authoritative source baseline: clean `main` at `b834a91` before the September
website-claim audit changes. This update supersedes the March 12 project-status
snapshot as the current planning reference; it does not erase the historical
record.

## Executive summary

Swarmfront has moved well beyond the March dash/bot transition described in the
old status document. The core gameplay, public-mode contracts, multiplayer
handshakes, mobile performance work, and authoritative Platform economy have all
received substantial implementation and test work.

The main distinction now is not “does the code exist?” but “has the exact feature
passed its remaining device, operational, governance, and public-enablement
gates?” Public modes and economy mutations remain default-off even where local,
service, and deterministic tests pass.

## Current product and engineering read

### Gameplay and match authority

- OpsState/SimState remain the authoritative gameplay state.
- Standard, Crucible, timed/async, CTF, HCTF, 3P FFA, 2v2, and 4P FFA paths have
  implementation and focused automated coverage.
- The current Standard buff path uses three loadout slots: two active at match
  start and the third unlocked in overtime.
- Standard loadouts now enforce no more than one Premium and one Elite in both
  profile persistence and authoritative match setup.
- Crucible suppresses buff selection, initialization, UI projection, and
  activation. The current public contract is Crucible 1v1, not team Crucible.

### Public modes

- The implementation sprint and integrated automated certification completed.
- The recorded staging posture remains `P5 PASS — P6 BLOCKED — P7 HOLD`.
- A current signed iOS development IPA and Release archive now exist; the exact
  candidate installs, launches, and remains alive on the paired iPhone. P6 still
  requires interaction evidence and the remaining physical-device matrix.
- P7 requires that evidence plus an explicit product-owner `GO` or `HOLD`.
- Repository defaults keep public 1v1, Crucible, multiseat modes, CTF/HCTF,
  public contests, bot fallback, and public leaderboards off.
- Human public HCTF has an additional secrecy boundary: the current peer model
  cannot prove that an opponent cannot inspect hidden state.

### Economy

- Platform economy authority, reset/recovery, session scopes, entitlements, and
  delivery infrastructure are implemented in the certification environment.
- The August 17 report remains the pre-canary read-only baseline.
- Bounded August 25 canaries subsequently enabled Nectar, Honey earn/spend, and
  Standard Wax in the protected certification environment. A fresh September 2
  read-only reconciliation is green.
- Crucible Wax remains independently disabled. The certification capability
  state does not enable public modes or constitute overall release approval.
- Legacy local economy code remains for compatibility/testing but is not the
  authoritative mutation path. Tests must assert that it fails closed when
  Platform authority is required.

### Mobile performance and builds

- Focused iPhone 16 Pro work isolated startup cost away from canonical simulation
  and removed measured synchronous texture-readback work.
- The custom Godot 4.2.2 iOS audio-start boundary passed the focused warm-device
  run.
- A current Release archive and development IPA now build and verify under
  signing. The exact app installs and launches on the paired iPhone; broader
  accepted device/build matrices remain unfinished and are still a release gate.
- iPhone, iPad, and Android are target platforms; this is not yet a claim of
  completed cross-platform public certification.

### Website and communications

- The Astro pre-launch site builds cleanly and runs locally on port 8080.
- Public copy now distinguishes implementation from public availability.
- A durable website claim ledger lives in `swarmfront-site/docs/CLAIM_LEDGER.md`.
- Real gameplay media, approved beta/contact destinations, social destinations,
  and deeper Game/Community/About content remain outstanding.

## September claim-audit corrections

The audit confirmed that much of the public copy was already supported by prior
testing. It also found two integration/documentation issues:

1. The one-Premium/one-Elite rule was implemented and tested in the removed
   EconomyBuffState autoload path, but the current profile/Arena wiring did not
   enforce it. A shared loadout policy now restores the rule in the live path,
   with regression assertions.
2. The isolated legacy economy smoke could emit assertion errors and still
   finish with exit code zero. A consumer audit confirmed that its state and UI
   were unreachable compatibility code already classified for deletion by the
   economy migration, so the legacy island was removed instead of retained as a
   second rules source.

The site also stopped implying that larger handshakes are merely unbuilt. They
are implemented and tested; certification/public enablement is the remaining
boundary. Team Crucible language was removed because the current contract is
only `CRUCIBLE_1V1`.

## Completed cleanup

- The unreachable four-slot `ModeRulesConfig`/`EconomyBuffState` implementation,
  its standalone panels/scenes, and its isolated smoke test were removed after
  confirming they had no current runtime consumers.
- The unused `data/buffs/buffs_v1.json` snapshot was removed. BuffDefinitions,
  BuffCatalog, BuffLoadoutPolicy, ProfileManager, and BuffState now form the
  traceable current path without a contradictory data snapshot.
- The current TestFlight checklist now points to the live buff inventory/wiring
  smoke rather than the deleted legacy-state smoke.
- Time-sensitive workstream documents should keep their historical decisions,
  with this rollup linking to the newest authoritative evidence.

## Proposed next steps

1. Exercise the installed signed iOS candidate and retain interaction/match
   evidence, then complete the rest of the Public Modes P6 physical-device matrix.
2. Record the P7 product-owner `GO` or `HOLD`; do not infer public readiness from
   automated tests alone.
3. Monitor and reconcile the four active certification economy capabilities;
   keep Crucible Wax disabled until its separate canary is authorized and passes.
4. Capture and approve genuine gameplay footage, then replace the website's hero
   and proof placeholders.
5. Approve beta intake, privacy/retention language, contact address, and official
   community destinations before enabling collection or links.

## Focused verification for this update

- `tools/buff_inventory_wiring_smoke_test.gd`: pass, including live profile and
  authoritative runtime tier-cap assertions.
- Legacy economy-buff consumer audit: no runtime consumers; redundant state,
  panels, data, and isolated smoke removed as previously classified by the
  authoritative economy migration.
- `tools/crucible_ruleset_smoke_test.gd`: pass.
- Focused CTF, HCTF, non-1v1 handshake, Free Roll Stage Race, and async
  money-ledger smoke tests: pass during the claim audit.

This focused verification supports the claims above; it is not a substitute for
the remaining release-readiness and physical-device gates.

## September 2 execution supplement

- Signed-candidate details:
  [P6 Signed Candidate Evidence](architecture/public_modes/p6-signed-candidate-evidence-2026-09-02.md).
- Current economy state:
  [Economy Canary Rollout Evidence](architecture/economy/canary-rollout-evidence-2026-09-02.md).
