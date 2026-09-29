# Main consolidation — completed September 29, 2026

The tested mobile beta baseline and the live backend's session-auth behavior
are consolidated on `main`. [PR #5](https://github.com/entap11/SF/pull/5)
merged as `3fed87cc6e2f18bf2ace7d57f680885600c123cc` after the final candidate
`478334b45a2e97f74126884ffd3f5c71070e4811` passed
[Release Readiness](https://github.com/entap11/SF/actions/runs/36508328666).

Branch and worktree cleanup is complete. `main` is the sole active local and
GitHub branch, and `SF/project` is the sole registered worktree. Unfinished
experiments were preserved in archive tags rather than integrated into the
tested game. The recovery catalog is
[`archive/2026-09-29/complete`](https://github.com/entap11/SF/tree/8152d8dfeb06eb8d4d0646c5438494891dad8d6e).

All five Render services reference `main`, with automatic deployment disabled.
The branch changes preserved the running releases. The authority's reproducible
build setup is recorded in [the deployment note](authority_render_build_2026-09-29.md).
The preparation history below is retained as evidence, not an outstanding task list.

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
feedback change. Uncommitted experiments were subsequently archived and their
extra worktrees retired during the September 29 cleanup.

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
Those were prior-baseline evidence at preparation time. The final candidate
subsequently passed the complete CI gate linked above.

## Pre-merge validation history

### Resumed validation on the home Mac

PR #5's initial Release Readiness run (`36501277935`) used the runner's
legacy PATH engine, `4.2.2.stable.official.15073afe3`, rather than the unified
mobile contract's `4.7.1.stable.official.a13da4feb`. Import reported unsupported
API/parse errors and the gate stopped in onboarding identity. This failed run
does not establish a regression under the supported runtime.

The pinned macOS engine was installed at the existing unified mobile toolchain
path after verifying the official release archive against its SHA-512 manifest.
The release-readiness CI job now selects that path by default, honors an explicit
`GODOT_BIN` repository variable, and rejects any version mismatch before import.
The actual workflow shell block was checked with both installed engines: 4.2.2
was rejected, and 4.7.1 passed and exported its path for subsequent steps.
No gameplay source, test assertions, or timing budgets changed. The corrected
candidate subsequently passed its full CI gate before merge. Original CI output
and resumed local checks are retained under
`SF/artifacts/branch-consolidation-2026-09-28/resume-checks/`.

## Completed landing checklist

- [x] Review and pass the complete release gate on the final PR candidate.
- [x] Merge PR #5 with preserved ancestry and align local `main` with GitHub.
- [x] Review every extra worktree; archive unfinished source and recovery evidence.
- [x] Retire extra branches and worktrees, including the final Render deployment branch.
- [x] Point all Render services to `main` with automatic deployment disabled.

Service rollout and store publication remain separate release operations.
