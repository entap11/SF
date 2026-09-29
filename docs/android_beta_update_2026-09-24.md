# Android beta update — September 24, 2026

Prepare Google Play version **0.1.3**, version code **26092401**, from the current
`codex/single-player-campaign` source. This includes the signup/session recovery
and Android credential discovery fixes, plus the current menu and hive polish.
The Android package remains `com.entap.swarmfront` and uses the permanent Play
upload certificate. This update does not advance the iOS preset.

## Build

The source must be committed and clean. Use the existing signed release launcher:

```sh
python3 scripts/dev/export_android_play_aab.py --check-signing
python3 scripts/dev/export_android_play_aab.py --output /absolute/path/swarmfront-0.1.3-26092401.aab
```

The launcher runs the required release checks, exports with pinned Godot 4.7.1,
verifies the packaged game, and signs with the upload key held outside the repo.
It does not upload to Google Play. Release artifacts and validation records belong
outside the source worktree, under `../artifacts/releases/0.1.3/` for this build.

## Update the existing Google Play test

1. Open Swarmfront in Play Console.
2. Under **Test and release → Testing**, open the same internal or closed test
   track that the beta tester already uses.
3. Create a new release and upload `swarmfront-0.1.3-26092401.aab`.
4. Add the notes below, review the release, and complete the rollout to that track.
   If Play requests review or a Publishing overview action, complete that step too.
5. Once Play makes the release available, the tester updates Swarmfront through
   the Play Store while signed into their enrolled Google account, then retries
   signup. An update should preserve the existing installation and device key.

Suggested release notes:

> Fixes account setup and improves sign-in recovery after restarting the app.
> Enlarges menu and game-mode buttons and improves hive visual feedback.

Reference: [Google Play release instructions](https://support.google.com/googleplay/android-developer/answer/9859348).

The size and spacing are provisionally accepted for layout. Restoring the existing
button artwork and the combined physical-device usability pass remain open;
generating this beta bundle does not close them. This document records the release
procedure, not a claim that the bundle has been uploaded or is available to testers.
