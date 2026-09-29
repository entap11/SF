# Swarmfront Sprite-Projection Readability Study

## Decision

**STOPPED AT GATE A — source viability failed.**

Neither decision structure has legitimate renderable source material in the approved baseline. Both are available only as flattened raster artwork, with no recoverable geometry, layered construction, source camera, or calibrated ground-plane setup. Producing alternate projections from those PNGs would require image warping, reconstruction, or invention and would not test the proposed projection change.

Per the defining plan, the study stops before metric preregistration, alternate rendering, static composites, or an interactive harness. No recommendation to change production projection can be supported from this baseline.

## Isolation and rollback boundary

- Approved starting commit: `32c0aafb154fd69ecc76db54a88f6381ae58b82b`
- Evidence worktree: `/Users/matthewballou/SideProjects/SF/project-sprite-projection-evidence-32c0aaf`
- Worktree state: detached at the exact approved commit
- Report state: uncommitted evidence only
- Production code, gameplay state, scenes, imports, and assets changed: **none**
- Original working tree files copied into this worktree: **none**

This evidence worktree is the complete rollback boundary. Leaving it in place has no effect on the game. After preserving any wanted report evidence, it can be removed from the main repository with:

```sh
git worktree remove --force /Users/matthewballou/SideProjects/SF/project-sprite-projection-evidence-32c0aaf
```

`--force` is necessary while this uncommitted report remains and will delete the report with the worktree.

## Environment provenance

- Audit time: `2026-07-15T16:22:53-07:00`
- Host: macOS 15.7.7, build 24G720, x86_64
- Godot: `4.2.stable.official.46dc27791`
- Blender: `4.2.17 LTS`, build `76b996a81c95`
- Authored viewport: 1080 × 1920 portrait
- Stretch configuration: `viewport`, `keep_width`
- Production texture imports for the selected PNGs: lossless compression mode 0, mipmaps disabled, alpha-border correction enabled, no premultiplied alpha, no size limit
- Rendering backend: not explicitly pinned in `project.godot`; no render was performed, so platform/backend variability did not affect this audit

## Decision assets

### Common hive — low-power small hive

Production identity:

- Manifest keys: `hive.small.neutral`, `hive.small.p1` through `hive.small.p4`
- Production raster: `res://assets/sprites/sf_skin_v1/hive_small_flatop.png`
- File properties: 1239 × 1269 RGB PNG, no native alpha
- SHA-256: `9b98eec98d43c5b8bb74c9bb7a1e8ed153d1c9d928df94b8d307d19fe44c300b`

The manifest applies a scale of 1.95 and a black color key (`threshold 0.035`, `softness 0.018`). `hive_visual.gd` selects the small tier for power 0–9, reads this manifest texture, and scales it to the requested display height with a 0.90 width factor. Those runtime operations place and present the flattened image; they do not recover its projection.

This is the appropriate common-structure candidate because it is the normal low-power hive and has a clearly baked three-quarter form.

### Tall/occlusive structure — large tower tier

Production identity:

- Atlas: `res://assets/sprites/sf_skin_v1/towers.png`
- Large-tier atlas region: `(970, 103.338, 426, 742)`
- File properties: 1536 × 1024 RGB PNG, no native alpha
- SHA-256: `ddadc0e8d089e559ed95a5aa4ae5532f53b3db5c153c089d9ab6c529e1a0a882`

`tower_renderer.gd` loads small, medium, and large atlas resources and selects the large tier for the upper tower range. Runtime presentation includes white-background keying, shadow treatment, base lift, and nonuniform pitch scaling (`x = 1.10`, `y = 1.44`). These transforms are not a reproducible source camera and cannot generate a controlled alternate projection.

The large tower is the appropriate tall candidate because it has the greatest baked vertical extent and likely projection overhang among the tower tiers.

### Bee — viewpoint-control only

- Committed control raster: `res://assets/sprites/mvp_unit2.png`
- Raster SHA-256: `5c404b853e02ee94453de7a4dcb70def110cdf8d21643fd804d1b7df62cf8ee4`
- Committed Blender source: `res://assets/blender/bees/bee_models_with_rig.blend`
- Blender SHA-256: `6be47fd53e08d737d0c0944ee5a08823360c788e79913b1e2b9bf954c4636c2f`

The repository contains two bee Blender files and their textures, but no documented source-to-production camera/render recipe tying them precisely to the current unit sprite. Additionally, the approved commit's unit manifest resolves current `unit.*` entries to `res://assets/sprites/sf_skin_v1/unit_v3.png`, which is absent from the approved commit. A file at that path exists only as untracked material in the original working tree and was deliberately not copied into the evidence worktree.

The bee is not a structure-conversion candidate and does not rescue the failed structure gate. Its source is sufficient to show that source preservation is possible, but insufficient to establish current production-view fidelity without the missing asset and pipeline mapping.

## Gate A results

| Requirement | Small hive | Large tower |
|---|---|---|
| Legitimate renderable or layered source | Fail — flattened PNG only | Fail — flattened atlas only |
| Recoverable source camera and projection | Fail | Fail |
| Controlled elevation/yaw changes | Fail | Fail |
| Ground-plane, origin, and footprint calibration | Fail | Fail |
| Reproducible baseline render for A/A-rendered comparison | Fail | Fail |
| Eligible for B/C projection variants | No | No |

Because neither decision structure passes Gate A, the entire study stops here. There is no valid path to the later gates from the approved evidence set.

## Source and pipeline audit performed

The audit covered:

- Current committed paths and asset manifests
- Godot scene/resource references and renderer code
- The complete Git object/history listing, including deleted-file history
- Git LFS-tracked files
- The full project directory outside `.git`
- Committed project archive listings
- Documentation and scripts for camera, render, export, or source-generation instructions
- PNG metadata for creator or source-location clues

Only two Blender files were found, both for bees. No hive or tower `.blend`, `.blend1`, `.fbx`, `.glb`, `.gltf`, `.obj`, `.usd`, `.psd`, `.kra`, `.xcf`, `.ai`, or `.svg` source was found. No reproducible hive/tower camera or render configuration was found.

## Work deliberately not performed

- No PNG skew, shear, squash, perspective warp, or repaint
- No generative reconstruction or image generation
- No inferred 3D geometry
- No alternate camera, gameplay camera, or world transform
- No production asset replacement or import mutation
- No gameplay, simulation, input, HUD, or renderer changes
- No A/A-rendered, B, or C variants
- No static comparison composites
- No interactive test harness
- No commits, branches, cherry-picks, pushes, or deployment

Because no presentation transform was introduced, input inverse-transform validation is not applicable in this stopped run. If a later study reaches a presentation-transform harness, hive selection, lane interaction, grab-throw deletion, buff targeting, all screen-to-world raycasts, and HUD/SubViewport boundary behavior remain mandatory proof points before acceptance.

## Minimum source package needed to resume

At least one decision structure must have:

1. Original 3D or genuinely layered source, including linked textures and materials.
2. Source camera projection, elevation, yaw, framing, and orthographic scale or focal settings.
3. Lighting, world/environment, color-management, renderer, and relevant application-version settings.
4. Ground plane, object origin, gameplay anchor, visible footprint, and footprint-calibration convention.
5. Baseline render resolution, transparency/keying, compositing, and export settings.
6. Provenance connecting the source and settings to the shipped raster closely enough for an A versus A-rendered fidelity check.

The narrowest legitimate recovery is to locate or export the original hive/tower source from the creator or content-generation workspace, package it with the settings above, approve its provenance, and rerun Gate A from this or another explicitly approved commit. The flattened PNGs should not be reverse-engineered into substitutes.

## Final recommendation by candidate

- Small hive: **source fidelity insufficient**.
- Large tower: **source fidelity insufficient**.
- Bee control: **source/pipeline limitations prevent a valid current-production compatibility conclusion**.
- Overall battlefield screen-angle experiment: **no decision; source fidelity is insufficient to enter the projection comparison gates**.

The safe result is to preserve the current production presentation and resume only when legitimate decision-structure source material is available.
