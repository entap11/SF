# Beta feedback and review report

Followup: the controls and feedback are now combined in development build
`2026092804`, with a passing full fast release gate and
[verified iPhone game/feedback uploads](bot_beta_phone_acceptance_2026-09-28.md). See the
[integration record](bot_beta_integration_2026-09-28.md) and
[next-session checklist](bot_beta_next_session.md) for current device status and
the real-player feedback still needed. The build `2026092803` evidence below is
the earlier feedback-only checkpoint.

Requested September 28, 2026: optional postgame feedback (challenge, interesting
opponent, control problems), self-reported experience, and an automatic private
report grouped by experience and bot personality. Current bot policies and input
controls are outside this change; another agent owns controls.

Feedback belongs to one player/capture and is stored separately from immutable
recordings. Local drafts/answers survive restart and offline play. The existing
sharing choice, authenticated upload, exact-hash acknowledgement and account
cleanup apply. The server owns accepted feedback; reports are rebuildable
projections. Operator owner labels always override self-reported experience.
Unknown answers remain unknown. Control-affected games cannot enter clean
performance comparisons. Raw measured durations are never adjusted.

Acceptance: client selection/skip/restart/identity/sharing behavior, separate
upload after recording receipt, immutable duplicate/conflict behavior, auth and
deletion, grouped report denominators, control annotations, version/map
separation, and reproducible review cues. Test the actual postgame launch and
mobile layout. Keep this isolated patch ready to integrate with the controls
fix; do not overwrite another agent's phone build.

## Player flow

Two seconds after a completed game, the beta offers three unrated questions:
challenge (too easy/about right/too hard), interesting opponent (yes/partly/no),
and controls getting in the way (yes/no/unsure). Experience can be new, some
experience, experienced, or prefer not to say; its last selection is remembered
for that local account. Ratings have no default answers. Save requires all three
ratings; Skip leaves the game unanswered. The panel scrolls on shorter screens
while Save and Skip remain accessible. A new game closes the prior prompt.

Draft selections and the pending invitation are saved atomically. Submitted
answers go to a separate `<capture_id>.feedback.json` queue file under the same
owner folder as game captures. Original gzip bytes remain unchanged. Feedback
waits for the game receipt, then uploads using the same session and sharing
choice. A wrong feedback receipt cannot delete either queue entry. Disabling
sharing leaves both kinds of evidence local. Account deletion removes prompt,
experience preference, queued feedback, and accepted server feedback.

## Server contract

`POST /v1/beta-captures/:captureId/feedback` accepts a bounded 2 KiB JSON body:

```json
{
  "schema_version": 1,
  "capture_id": "32-lowercase-hex-characters",
  "owner_key": "64-lowercase-hex-characters",
  "answers": {
    "experience": "new",
    "challenge": "about_right",
    "interesting": "yes",
    "controls": "no"
  }
}
```

Player session auth, owner/capture matching, exact body hash, field allowlist and
all enums are validated. The existing archive/account lock serializes acceptance
with account deletion. Same bytes can retry after a lost receipt; different
answers for an already accepted capture return 409. A missing capture returns
404 and remains queued for retry. Feedback cannot assign the operator-owned
`owner` cohort. Admin archive listings include the answers and server receipt
time; gzip downloads are unchanged. No free text or new identifying fields.

Migration `013_beta_match_feedback.sql` adds nullable feedback/receipt fields to
`sf_beta_captures`; the existing recording deletion removes them. Apply through
the existing database owner before deploying the service. Existing table grants
cover the new fields; no broader runtime privileges are needed. It was applied
to `swarmfront_cert` with both existing recording payloads and hashes checked
unchanged. Migration SHA-256:
`7e7b8219b01abfc1964687d212a440b7eb4501a4562c67c19f2f6991a3447374`.

## Report generation and interpretation

Every `tools/collect_beta_games.py` archive pull now writes `report.md` and
`report.json`, alongside the existing private exports. No public dashboard or
scheduled unattended downloader is introduced. To rebuild without a network:

```sh
python3 tools/beta_game_report.py --archive ../artifacts/beta-games
```

Both tools accept `--annotations <private-json>` and `--manifest <exact-build-json>`.
The default annotation file is `<archive>/annotations.json`. An annotation is
keyed by archive ID and must contain the matching `capture_id`, for example
`{"1": {"capture_id": "...", "control_affected": true}}`. Review annotations
remain separate from player answers and original recordings. Keep the annotated
archive directory when refreshing, or pass its annotation file explicitly.
An exact source manifest can resolve a legacy missing map hash only when its
source fingerprint matches the recording. Future playtest captures now include
the map path/hash and leave absent shared session keys empty.

Reports separate experience/cohort, personality/policy/tier/seat, build/source,
map fingerprint, mode and human seat. An operator cohort takes precedence over
self-report; owner stays owner. Missing/unsure controls answers remain unknown.
Only completed one-human/one-bot recordings with an explicit controls="no" and
no contrary annotation enter clean duration/win summaries. Other games and all
answers remain visible with their own denominators. Counts represent participant
recordings, not unique multiplayer matches. The participant count prevents
multiple games by one expert from appearing to be many independent testers.

Review cues use analysis thresholds, not gameplay constants:

- No new accepted bot order for at least 30 seconds while the bot has hives.
  Existing routes may still be productive; this is not labeled proof of idleness.
- No observed outgoing route for at least 30 seconds without an accepted order.
  Travelling units are absent from the projection, so inspect the game.
- Three repeated rejected orders in 30 seconds.
- Three repeated attack/swarm orders against the same non-owned target in 30
  seconds with no sampled capture or net target-power reduction. Defensive
  swarms toward a bot-owned target are excluded. Combat can still justify these
  orders; this is a review lead, not proof of wasted actions.

Coverage loss and missing map identity are also flagged. Behavioral cues are
suppressed when events are dropped or board frames are downsampled. No cue automatically
changes difficulty. The initial report on the two owner uploads correctly marks
Balancer as control-affected, Raider's controls as unanswered, and both cohorts
as owner. It highlights Balancer's repeated 6→4 pressure at 71.6–86.1s for review,
without calling it a bug or recommending stronger medium bots.

## Validation and integration

Evidence lives under `SF/artifacts/beta-feedback-2026-09-28/`:

- `report-tests.log`: eight regression tests cover owner isolation, response and
  clean-sample denominators, annotations/digests, source/map/seat separation,
  multiplayer handling, active routes versus no routes, repeated pressure versus
  defensive swarms, elimination timing, and suppressed behavioral flags under truncated coverage.
- `transport.log`: actual Godot UI draft restoration, answer queue, sharing,
  identity scope, skip, capture-before-feedback ordering, failed game response,
  wrong feedback hash, and successful receipt cleanup passed with four real
  loopback HTTP requests. Synthetic isolated identity; no live feedback posted.
- `backend-smoke.log`, `deletion-smoke.log`, `deploy-smoke.log`,
  `deploy-deletion.log`: embedded PostgreSQL and HTTP checks passed, including a
  second authenticated player being unable to annotate the first player's game,
  schema/privacy/size rejection, duplicate/conflicting answers, original digest
  preservation, owner-label preservation, session revocation, and purge.
- `ui-evidence.json`, `feedback-phone.png`, `feedback-compact.png`: actual Godot
  rendering and layout assertions at 1080×1920 and 1080×1080. Selected choices
  have a visible gold border; ratings begin unselected. This is desktop-rendered
  mobile layout evidence, not a physical-phone feedback submission.
- `arena-final.log`: both real Arena test flows reached terminal capture and feedback;
  map identity, receipt association, submit/skip, and existing postgame navigation
  passed. Existing headless shader/resource-shutdown diagnostics remain visible.

The feedback change lives on `codex/beta-match-capture-20260928`; its backend is
isolated on `deploy/beta-capture-20260928`, preserving live identity fixes.
Integration touches `BetaMatchCapture`, account-deletion cleanup, two new
feedback scripts, beta build/export metadata, archive service/migration, review
tools and focused tests. It does not edit Arena, input controls, bot policies,
map bytes, or OutcomeOverlay. Use the feedback commits with the other agent's
control changes, then regenerate the source manifest and run the combined
release checks before distributing the beta. The prepared development package
is not automatically installed over the other agent's phone build.

Backend deployment `dep-datcl7qd0e5s73bijqu0` is live at commit
`24e173ba1ff5f6bf9f31a8b39cd628cdd45af3c5`. `live-verification.json` confirms the
exact build, authenticated admin export with nullable feedback fields,
unauthenticated upload rejection, unchanged original recording hashes, and
unchanged economy/verified-result mutation flags. No synthetic answers were
posted to live player records. The generated owner report is in
`live-archive/report.md` and `live-archive/report.json` under the evidence folder.

Development build `2026092803` exported and built successfully. Code-signature
verification, embedded/exported PCK equality, and inspection of the packed
feedback scripts and source manifest passed (`export.log`, `xcode-build.log`,
`package-check.log`, `app-verification.json`). Source fingerprint:
`b9e5de578cdb0fed8a989f28f8b340830413b1e83635006eadbf4f40773b502b`.
The `.app` is under `DerivedData/Build/Products/Debug-iphoneos/Swarmfront.app`.
It has not been installed over the controls agent's work. The integration build
must take a fresh unused build number and regenerate its manifest.

The broader fast release gate was rerun: campaign fingerprints and beta source
manifest passed, followed by signup and offline restart checks. The online
onboarding restart then hit the existing runner's 90-second process timeout
(`fast-gate.log`). The cause is not established. This remains an incomplete
release gate, not a passing store candidate. The dedicated feedback, report,
transport, Arena, backend, deletion, layout, and package checks passed. No real
phone feedback submission is claimed yet.
