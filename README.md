# Swarmfront branch archive — September 29, 2026

The owner chose to archive unfinished work and keep the tested game on `main`.
The tested baseline is `3fed87c`, which merged PR #5 after Release Readiness
passed. `SF/project` is the canonical development checkout after cleanup.

The tags under `archive/2026-09-29/branches/` preserve original branch tips.
The tags under `archive/2026-09-29/wip/` preserve every tracked modification
and non-ignored untracked file from the 16 dirty working trees. WIP snapshots
are recovery references, not validated features or changes merged into main.
`catalog.json` maps every archived branch and working tree to its exact commit.

## Restore unfinished work

Fetch the archive tags and create a fresh branch/worktree from the relevant tag.
For the unfinished buff UI/effects work:

```sh
git fetch origin --tags
git worktree add -b resume/buff-ui ../project-resume-buff-ui archive/2026-09-29/wip/project-unified-mobile-release
```

For the separate map-authoring feature:

```sh
git worktree add -b resume/map-authoring ../project-resume-map-authoring archive/2026-09-29/branches/codex/map-authoring-symmetry
```

Other tag names are in `catalog.json`. A snapshot includes its original base
history, so ordinary diff/cherry-pick/rebase tools can be used to review it.
Do not merge an archived prototype just because its source has been preserved.

## Local recovery evidence

`SF/artifacts/branch-cleanup-2026-09-29/` contains:

- `recovery.bundle`: a verified full Git bundle, including original history
  and the archive refs available when it was created.
- `snapshots/<old-worktree>/`: exact changed-file tarballs, staged/unstaged
  patches, and manifests with file hashes. Original index state is documented.
- `preserved-local/<old-worktree>/`: ignored build outputs, local configuration,
  and review evidence moved out of retired trees. These files are kept locally
  and are not uploaded as source. `preserved-local.jsonl` records hashes and
  rename checks. Restore relevant paths into a recreated worktree if needed.
- `inventory.json`, `refs-before.json`, and final cleanup results: audit trail.

Generated `.godot`, `node_modules`, Python caches and `.DS_Store` files in
retired worktrees can be regenerated and are removed with those worktrees.
The primary `SF/project` checkout's ignored files remain in place.

## Deployment exception

Keep remote `deploy/staging-cert-20260720`: three Render certification services
still reference it with automatic deploys disabled. This cleanup does not alter
service configuration or deploy code. Other retired development/deployment
branch names remain recoverable through archive tags.
