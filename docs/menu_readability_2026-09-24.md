# Home and mode-selector readability — September 24, 2026

September 25 update: the owner prioritized restoring the existing button artwork
to review its fit before further menu polish. The [artwork fit pass](menu_artwork_fit_2026-09-25.md)
supersedes the placeholder-art implementation below; visual acceptance remains open.

The owner requested larger, more readable buttons on home and especially inside
Free Roll and Money Games, with freedom to change the layout. The owner then
proposed clusters of roughly five large hex-shaped options to reduce scrolling.
Physical-device validation is explicitly deferred to a combined pass.

Owner clarification: the plain hex panels are acceptable for layout review.
Before finalizing these menus, restore the existing Swarmfront button artwork
and enlarge it with the buttons. Preserve the clustered layout, readable labels
and generous touch targets. The current panels are layout placeholders, not the
approved final art treatment; artwork restoration remains required work.

Owner density direction: buttons should largely fill the available space, with
small, consistent gaps. Extra viewport height belongs to the choices, rather than
an empty area below them. Existing artwork must fill these enlarged targets when
it returns. The follow-up review is `../artifacts/menu-density-2026-09-24/index.html`.
Both native menu and lobby checks passed for that refinement, with 29 before/after
screen pairs; the review's verification record identifies the tested source.

Owner review: the revised size and spacing look right for the layout pass.
Treat this as the provisional baseline while restoring the artwork. Final
readability, touch spacing and usability acceptance remain with the combined
physical-device pass; desktop captures do not close that validation.

## Current implementation

Home gives Campaign a full-width primary entry with the existing Continue level,
followed by larger Free Roll, Money Games and Tournament entries. Dashboard, Hive,
Store, Buffs and Battle Pass remain reachable in a persistent footer. The existing
wordmark is retained. Rank, tier and honey are compact, actionable projections.
The latest replay becomes a secondary entry; an empty replay no longer dominates
home. The replay opens the existing player and closes back to home.

Free Roll groups existing routes under Live Matches, Contests and Bot Modes.
Money Games groups them under Live Matches and Contests. Related choices use
clusters of up to five native buttons with wide hex frames and live text.
The default portrait arrangement is two–one–two for five options. The review also
shows the owner's three-over-two direction at the same type size. Smaller groups
contain only their actual choices; there are no placeholder options.

Mode text stays at 44 authored units, with 32-unit supporting copy. Default hexes
have a minimum height of 188 units and expand to fill the available menu height.
Spare height is shared per row across the visible clusters, with 12-unit gaps.
Home play choices also expand, with larger persistent footer controls.
Their rectangular touch bounds never overlap, and scroll
drags retain the existing release guard. Back remains outside the scrolling
content; Escape and Android Back also close the mode selector. The paid selector
keeps entry amounts, selected division/tier, locked access and add-funds states
explicit. Existing status messages remain visible above Back.

The menu presentation reuses the existing buttons and their route callbacks.
Campaign/progression, modes, eligibility, denomination availability, entry gates,
wallet transactions and settlement are not redefined. The existing authoritative
systems continue to own those behaviors. The styling builds on UITypography and
the palette in the Game Skin; the hex frame redraws on interaction/resize events.

## Review and verification

Native comparison and screen matrix:
`../artifacts/menu-polish-2026-09-24/index.html` relative to the worktree.

The isolated runner disables hosted services and uses disposable player data.
Money Games captures use a clearly identified local wallet fixture; they do not
demonstrate a real account balance, purchase or service settlement.

The new layout/route check requests windows at 1080×1920, 944×2048, 720×1280 and
1080×1500. Existing viewport scaling retains a 1080×1920 render surface for the
standard, small and short references; the tall reference renders at 1080×2343.
Physical target sizes remain for the device pass. The check covers
Campaign and Dashboard return paths, all 19 Free Roll choices, both
cluster arrangements, mode-label fit, non-overlapping targets, persistent Back,
scroll-release cancellation, paid division/tier updates, locked access and the
existing insufficient-funds route. Focused legacy checks retain route and
eligibility assertions while replacing obsolete baked-art/layout expectations.
See the artifact's verification manifest and logs for the final check results.

Final result: the native menu-polish check and nine focused regression checks
passed, including Campaign, Tournament, Gauntlet and stage-race routing. Python
compilation, review-page JavaScript syntax, artifact links and `git diff --check`
also passed. Existing Gauntlet launch assertions remain covered separately from
its current public-contest menu entry.

The baseline includes the pre-pass main-menu source and native home capture.
Hash verification preserves 119 simulation/state/pressure sources from the
preceding selection/capture pass. Native captures are visual evidence, not device
performance evidence. The known asset UID/Unicode warnings remain; headless runs
allow only the previously documented Godot custom-sampler diagnostic.

Reproduce:

```sh
python3 tools/run_menu_polish_checks.py --godot /path/to/Godot --output /tmp/menu-review --capture --test main_menu_polish_smoke_test
python3 tools/run_menu_polish_checks.py --godot /path/to/Godot --output /tmp/menu-checks --test campaign_ui_smoke_test --test main_menu_money_games_contest_menu_smoke_test
```

The [setup/lobby pass](lobby_readability_2026-09-24.md) now extends this work through
free/paid setup, lobbies, contest entry/details and insufficient balance. Results
and retry are next, followed by the remaining Dashboard/utility screens.
The full menu migration and
integrated phone review are not claimed complete by this home/mode-selector pass.
