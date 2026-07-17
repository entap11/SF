# Game-ready bee models

- `bee_high.glb` is the 19.5k-face rigged garage hero. It retains the authored
  wing animation and uses embedded textures capped at 1024 px.
- `bee_low.glb` is the 1.6k-face rigged gameplay candidate with embedded
  textures capped at 512 px. It is intentionally not enabled in the live swarm
  renderer yet; that conversion needs batching and device performance testing.

The GLBs are generated from the canonical files under `assets/blender/bees/`.
Regenerate them from the repository root with:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  -b assets/blender/bees/bee_models_with_rig.blend \
  --python tools/export_bee_models.py -- low assets/models/bees/bee_low.glb

/Applications/Blender.app/Contents/MacOS/Blender \
  -b assets/blender/bees/bee_models_cinematic_teaser.blend \
  --python tools/export_bee_models.py -- high assets/models/bees/bee_high.glb
```
