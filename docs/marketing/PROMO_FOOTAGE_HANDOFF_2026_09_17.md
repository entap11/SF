# Promo footage handoff — September 17, 2026

The current promotional direction is **1.75× gameplay playback**. The user
preferred the earlier 1.5× edit and requested that pace or slightly faster across
all promotional material, to convey the urgency of making decisions during play.
This is an editing choice; simulation speed and gameplay rules were not changed.

## Current delivery

The reusable media library is stored locally outside Git:

```text
~/Desktop/SF Art/swarmfront-media-2026-09-17/
```

Open `11_launch_set_v2_fast/WATCH_FIRST.html` for the current review page.
It contains 53 checked MP4 exports:

- 18 versions of the seven launch edits: one hero, three gameplay proofs, and
  three social edits, including clean masters and website/social compositions.
- 35 accelerated versions of the original highlights, candidates, overview and
  trailer cuts. The overview/trailer pieces retain their rough-cut status.

All promotional gameplay runs at 1.75×. Social brand endings remain two seconds;
audio follows the faster picture with pitch preserved. Use the existing speed
and scripted-development labeling. Clean files require that context in their
accompanying page or post copy.

The source library retains eight complete normal-speed matches, original AVI
captures, cleaned MP4 playback copies, separate audio, stills, event traces, and
the earlier normal-speed/1.5× launch edits. Do not add these large media files to
this repository as part of an ordinary source checkpoint.

## Provenance and limits

Every match has two scripted participants and uses the development build at
`3447930035e96e5cfe9dd8f9838dec74ebd6535e` plus the frozen working tree. The library
contains its frozen source snapshot and exact capture drivers. Game-state changes
during capture were issued through the normal simulation intent path.

These recordings do not establish human PvP, touch-input behavior, or physical
device performance. Additional modes and supporting shots are listed in
`00_manifest/GAPS_AND_NEXT_CAPTURES.md`. Media was not deployed to the website or
posted to social accounts during the editing task.

## Reproduction and validation

The library includes the capture/export programs under
`09_audio_captions_projects/`, and current editing programs under
`11_launch_set_v2_fast/project/`. The latter contains source-frame edit decisions,
the 35-file source mapping, renderer, packaging script, media checks, and browser
checks. Run those scripts in the documented library layout; the README explains
the Python, FFmpeg, Godot and font requirements. No Resolve operation is needed.

All 53 current MP4s passed full decoding, frame-count/duration, dimensions,
30 fps, square-pixel, Rec.709 and audio checks. The review page passed Chrome
desktop/mobile viewport checks, reduced-motion behavior, all ten players, and
pause controls. These are browser viewport checks, not device certification.

Evidence, checksums and screenshots are retained in
`11_launch_set_v2_fast/quality/`. Future editors should first read
`PROMO_EDITING_DIRECTION.md` in the library root.
