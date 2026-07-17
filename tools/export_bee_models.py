"""Export the authored Blender bees as compact, Godot-ready GLB files.

Run from the repository root with Blender, for example:

    /Applications/Blender.app/Contents/MacOS/Blender \
        -b assets/blender/bees/bee_models_cinematic_teaser.blend \
        --python tools/export_bee_models.py -- high assets/models/bees/bee_high.glb

The source .blend contains both bee tiers and a studio plane.  This exporter
keeps only the requested rig and its children, embeds resized texture copies,
and leaves the canonical Blender files and source textures untouched.
"""

from __future__ import annotations

import os
import sys

import bpy


RIG_BY_TIER = {
    "low": "Rig_3k_bee_low",
    "high": "Rig_30k_bee",
}

MAX_TEXTURE_DIMENSION_BY_TIER = {
    "low": 512,
    "high": 1024,
}


def _args() -> tuple[str, str]:
    if "--" not in sys.argv:
        raise SystemExit("Expected: -- <low|high> <output.glb>")
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 2 or args[0] not in RIG_BY_TIER:
        raise SystemExit("Expected: -- <low|high> <output.glb>")
    return args[0], os.path.abspath(args[1])


def _descendants(root: bpy.types.Object) -> set[bpy.types.Object]:
    result = {root}
    pending = list(root.children)
    while pending:
        obj = pending.pop()
        if obj in result:
            continue
        result.add(obj)
        pending.extend(obj.children)
    return result


def _resize_linked_images(objects: set[bpy.types.Object], max_dimension: int) -> None:
    materials = {
        slot.material
        for obj in objects
        if obj.type == "MESH"
        for slot in obj.material_slots
        if slot.material is not None
    }
    images = {
        node.image
        for material in materials
        if material.use_nodes and material.node_tree is not None
        for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE" and node.image is not None
    }
    for image in images:
        width, height = image.size
        longest = max(width, height)
        if longest <= max_dimension or longest <= 0:
            continue
        scale = max_dimension / float(longest)
        image.scale(max(1, round(width * scale)), max(1, round(height * scale)))


def main() -> None:
    tier, output_path = _args()
    rig = bpy.data.objects.get(RIG_BY_TIER[tier])
    if rig is None:
        raise SystemExit(f"Missing expected rig: {RIG_BY_TIER[tier]}")

    export_objects = _descendants(rig)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in export_objects)
    bpy.context.view_layer.objects.active = rig

    for obj in export_objects:
        obj.hide_set(False)
        obj.hide_render = False

    _resize_linked_images(export_objects, MAX_TEXTURE_DIMENSION_BY_TIER[tier])
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_animations=(tier == "high"),
        export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True,
        export_frame_range=True,
        export_skins=True,
        export_all_influences=False,
        export_morph=True,
        export_lights=False,
        export_cameras=False,
    )
    print(f"SF_BEE_EXPORT tier={tier} objects={len(export_objects)} output={output_path}")


if __name__ == "__main__":
    main()
