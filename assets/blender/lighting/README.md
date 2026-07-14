# Blender lighting environments

- `studio_small_09_2k.hdr` - 2048 x 1024 environment for previews and faster iteration
- `studio_small_09_4k.exr` - 4096 x 2048 version of the same environment for final renders

The bee Blender sources currently reference `../HDRI - STUDIO.hdr`, which is a
different 2048 x 1024 environment. These `studio_small_09` files are preserved
as alternate lighting options and do not silently replace the authored setup.
