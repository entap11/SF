# Combined controls and bot-feedback build

Development build `2026092804` combines the beta capture/feedback source at
`07b096d`, the tutorial/map work at `7e50220`, and the controls working-copy
changes confirmed ready by the owner. It lives on
`codex/bot-beta-integrated-20260928` in `SF/project-bot-beta-integrated-20260928`.
The original controls and feedback checkouts are preserved. The approved input
patch and file hashes are retained under
`SF/artifacts/beta-integration-2026-09-28/`.

## Resulting behavior

- Dragging from an enemy/neutral destination back to an owned source retracts
  the player's existing incoming lane without authorizing foreign commands.
- Finger motion that stays inside the pressed hive still permits tap/tap
  commands and friendly feed reversal.
- The approved swarm changes preserve excess arriving bees through the relay
  window, account for them once, and release expired overflow through the
  simulation. GameState and OpsState snapshots include that state.
- Tutorial highlights use the HUD coordinate space; prompts recover from
  cancelled gestures and guide successive swarms. The tutorial followup uses
  Simple Syrup. The associated map additions/aliases are retained.
- Automatic capture, independent optional feedback, sharing choice, and private
  reports remain present. No backend redeployment is needed for this integration.

The bot policy files and seven-hive Simple Syrup comparison map are unchanged.
Do not use the owner's wins to raise medium difficulty. The new source/build
fingerprint keeps these games separate from recordings before the control and
swarm changes.

## Integration checks

The input-test conflict retained both branches' cases. The later readability
case now uses the fixture's 64-pixel coordinates and enters a real pointer press
before testing drag validation, which now depends on the active player. The
initial merged test caught that missing context; no gameplay change was made
to satisfy the test.

Passed on the combined source:

- Controls, swarm capture/relay/overflow, and 166 tutorial-input assertions.
- All 100 bot runtime checks and beta-capture privacy/receipt checks.
- Feedback layout/selection and both actual Arena match-to-feedback flows,
  including completed-recording association, save, skip, and return navigation.
- Four loopback HTTP requests verify separate game/feedback receipts, failure
  retry, and retention after an incorrect feedback hash. Report regressions pass.

Evidence is in `artifacts/beta-integration-2026-09-28/combined/`. Existing
headless shader and Arena shutdown diagnostics remain in the logs; these are
functional checks, not physical-phone feedback acceptance.

The earlier 90-second online-restart timeout did not reproduce in the isolated
four-process rerun or the combined gate's onboarding stage. All twelve
onboarding/account executions passed with the original timeout. Sampling during
the investigation observed desktop menu resource loading, including a 24 MiB
text font; this does not prove the cause of the earlier timeout. No authentication
code or timeout budget was changed. A preliminary gate on the feedback-only
source was deliberately stopped once the controls were confirmed ready, so
the complete gate could run on the combined source.

The combined full fast release gate passed: campaign/source fingerprints,
onboarding/account checks, all five lane/input/readability regressions, MVP
startup/completion, launch contract, 15 configuration contracts, eight
configuration startup/runtime cases, and three fast soak routes. The gate's
optional extended performance soak and TestFlight preflight were not enabled;
this is a development phone build, not a store publication. The passing result
is retained in `combined/fast-gate.log` and `combined/fast-gate-result.json`.

The iOS export and Xcode development build succeeded. Deep/strict signature
verification passed. The embedded/exported PCKs match at SHA-256
`ec3dae5aa24d49c5887a067f3f0cd70c61090a452045e50caea81b50d8586616`;
the packaged manifest, feedback/control scripts, and exact comparison map were
checked. No test override is packaged. Build source commit: `86c1564`.

The app was installed as an update on Matthew's iPhone 16 Pro, without uninstall
or account reset. The device app listing confirms `com.matthew.swarmfront`,
version `0.1.3`, build `2026092804` (previously `2026092802`). The foreground
launch request was rejected because the phone was locked
(`FBSOpenApplicationErrorDomain` code 7). The owner subsequently opened the app
and completed both evaluation games. The original tool launch result remains
recorded accurately. Device installation evidence is in
`phone-install.json`, `phone-launch.json`, `phone-apps-after.json`, and
`app-verification.json` under the integration artifact directory.

Physical-phone capture and feedback acceptance passed: both completed games
arrived from the exact build/source/map, and the Raider answers reached the
server independently. Balancer lasted 80.1 seconds and Raider 94.1 seconds;
both were owner wins. Raider feedback was too easy, interesting, no control
problems, and experienced. The owner missed the first feedback prompt before
Raider began and considers the timing acceptable; that response remains
unanswered, without marking the match as distracted or control-affected.

The private `phone-review/` export includes unchanged original recordings,
receipt metadata, annotations, the generated report, and a reproducible
`review.py`/`review.json`. See the [phone acceptance review](bot_beta_phone_acceptance_2026-09-28.md).
An offline/reconnect exercise on the physical phone is not established by these
games. Wider difficulty calibration still needs newer/intermediate players.

Source fingerprint:
`6d8a1190cc0a9cdbe9659c53ebb120dde2265ec2cae00d53a61172516c8eb562`.
Campaign definitions are unchanged; only their generated comparison fingerprint
was refreshed to reflect the integrated simulation source.

See [the next-session checklist](bot_beta_next_session.md) for the remaining
newer/intermediate-player sample and optional physical-phone reconnect check.
