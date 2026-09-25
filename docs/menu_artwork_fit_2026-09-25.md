# Menu button artwork fit — September 25, 2026

The owner moved this ahead of results/retry: restore the existing Swarmfront
button artwork and assess layout and fit before further menu polish.

## Implemented

- Home's Free Roll, Money Games and Tournament sprites sit beside their live
  labels and descriptions. Store, Buffs and Battle Pass art fills the utility
  buttons above the live labels. The original registry textures use the existing
  black-only transparency treatment, preserving silver that the former bottom
  navigation's neutral-color treatment removed.
- Free Roll and Money Games mode sprites replace the resting placeholder hex
  frames. Live names, map counts, context and paid entry details remain below
  the art. The two bot flag routes reuse the corresponding existing flag sprites.
- Transparent source padding is excluded from the displayed texture region.
  Sprites keep their original aspect ratios. No raster asset files are changed.
- Cluster rows respect each button's minimum height (312 authored units for
  art plus live copy), so dense paid-contest lists scroll rather than squeezing
  their artwork into the former 188-unit minimum. The 2–1–2 layout, category
  structure, generous touch targets and persistent Back remain.
- Campaign keeps its approved live heading and context. There is no Campaign
  sprite in this asset set; the former button art explicitly says Map Jukebox.
- Existing callbacks and native controls retain routing, eligibility, entry
  amounts, scrolling guards and focus. No authoritative gameplay or economy
  source is changed. Results/retry and other menu surfaces are outside this pass.

## Review

`../artifacts/menu-artwork-fit-2026-09-25/index.html`, relative to the worktree,
compares native captures against the accepted placeholder layout. It includes
home, every Free Roll category, the 3–2 alternative, paid modes/contests, entry
states and tall/small window references. The before captures were taken from
source `13633b2` immediately before this change with the same isolation runner.

Reproduce:

```sh
python3 tools/run_menu_polish_checks.py --godot /path/to/Godot --output /tmp/menu-artwork/final --capture --test main_menu_polish_smoke_test
python3 tools/build_menu_artwork_review.py /tmp/menu-artwork
```

The review builder also needs the corresponding pre-change captures under
`baseline/`. Runtime identity, source/capture hashes and check results belong in
the artifact's `verification.json`.

Verification: the native menu layout/route check passed with 14 captures; the
existing Free Roll layout/route and Money Games contest-menu checks also passed.
The native check was rerun after scoping texture caches to each menu's lifetime.
Python/JavaScript syntax and `git diff --check` passed. Existing Godot asset UID
and Unicode warnings remain; the final native run has no engine or script errors.

Native desktop captures use disposable player data and offline services; paid
screens use a local wallet fixture. Visual acceptance and the combined iPhone /
Android readability, touch and performance pass remain open. Window references
retain the game's existing viewport scaling and do not prove physical target size.
