# Swarmfront bee Blender sources

These files are the canonical Blender sources for the Swarmfront bee models:

- `bee_models_cinematic_teaser.blend` - cinematic setup with 17 actions
- `bee_models_with_rig.blend` - rigged model source

Both sources contain 36 objects and two armatures and were verified with
Blender 5.0.1. The available external 4K texture maps are stored in the same
relative locations expected by the original files. Keep those paths intact
when moving or packaging the sources.

The low-poly metallic and opacity originals are preserved under
`Blender low poly/`. Compatibility copies use the legacy `textures_3k` names
expected by the Blender sources, so their active material references resolve
without modifying the source `.blend` files.

One unresolved legacy image reference remains:

- `E:/Projetos Blender/fundo infinito/../HDRI/IMAGEM HDR - ESTÚDIO.hdr`

It is an unused lighting reference rather than a bee surface map; the active
studio lighting uses the repo-local `../HDRI - STUDIO.hdr`.
Raw Blender sources are excluded from Godot's automatic resource scan by the
parent `.gdignore`; export game-ready meshes separately when needed.
