shader_type canvas_item;
render_mode blend_mix;

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    // Optional: kill truly-near-zero haze (keep low)
    if (c.a < 0.02) discard;

    // Key fix: premultiply to remove halo/box from dirty transparent RGB
    c.rgb *= c.a;

    COLOR = c;
}
