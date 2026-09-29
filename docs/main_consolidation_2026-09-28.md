# Main consolidation candidate — September 28, 2026

This candidate brings `main` up to the mobile beta baseline already tested on
the owner's iPhone, while retaining current `main` and the live backend's
session-auth behavior. It is prepared on `codex/main-consolidation-20260928`
for a draft PR; the complete release gate on the final candidate remains a
pre-merge requirement.

## Included history and resulting behavior

- Tested integration: `2ece4c4`, containing the mobile 0.1.3/Godot 4.7.1
  baseline, campaign and menu/buff presentation work, bot behavior and Simple
  Syrup evaluation, approved controls/swarm fixes, and beta capture/feedback.
  Its three local-`main` commits are already ancestors of this candidate.
- Current remote `main`: `26dfcc6`, including the branding assets and
  deterministic-replay social planning documents. Merge commit: `57f7140`.
- Live beta backend: `24e173b`, including scoped account deletion, session
  revocation, private capture, and independent feedback. Merge commit:
  `96a8c43`. Its only additional file-content change versus the tested
  integration is the existing `IdentitySessionError` handling in
  `platformFailure`: revoked sessions receive the intended auth rejection
  rather than being treated as an unexpected server error.

Both merges completed without conflicts. Before this handoff document, the
candidate changes eight files relative to the tested integration: five
branding assets, two planning documents, and that backend error handler. The
client scripts, scenes, maps, data, and export/project settings are identical
to the tested integration. Medium bot policies retain the owner calibration
decision; source fingerprint remains
`6d8a1190cc0a9cdbe9659c53ebb120dde2265ec2cae00d53a61172516c8eb562`.

The full change against remote `main` is larger: 32 existing integration
commits plus the backend and merge history. Before this handoff document it
spans 1,374 paths, including 982 Godot import/UID metadata files. Review this
as consolidation of the current mobile baseline, not as only the recent bot
feedback change. Uncommitted experiments and active work remain in their
existing worktrees.

## Preparation checks

Passed on the combined candidate:

- Ancestry checks for remote `main`, local `main`, the tested integration, and
  the live backend deployment tip.
- Campaign fingerprints and beta source manifest; no regeneration required.
- Rank-service TypeScript build and player-token, embedded-session,
  account-deletion, beta-capture/feedback, and economy-quarantine smoke tests.
- Eight beta report regression tests.
- Exact client source comparison to `2ece4c4`; `server.ts` also matches the
  live deployment source byte-for-byte.
- Whitespace check of the consolidation delta. The full historical diff
  against `main` retains older Markdown hard-break/trailing-blank notices.

Local command results and logs are retained under
`SF/artifacts/branch-consolidation-2026-09-28/preparation-checks/`.
The earlier combined build's full fast release gate and real iPhone feedback
acceptance are documented in
[the integration record](bot_beta_integration_2026-09-28.md) and
[the phone acceptance review](bot_beta_phone_acceptance_2026-09-28.md).
Those are prior-baseline evidence; the complete gate has not been rerun locally
on this final consolidation candidate during preparation.

## Before merge

1. Review the full consolidated change and obtain a passing release gate on
   the final candidate. Check the PR's CI result separately from the focused
   local preparation checks above.
2. Use a merge commit when landing this consolidation so the preserved branch
   ancestry remains available for cleanup. Align the local `main` checkout
   after remote `main` contains the result.
3. Review remaining worktrees individually before retiring branches. An
   ancestor branch tip does not establish that its uncommitted files can be
   removed. Deployment history is included for correctness; service rollout
   and store publication remain separate operations.
