shader_type canvas_item;

uniform float band = 0.18;   // 0.05..0.35  (thickness of visible center)
uniform float feather = 0.10; // 0..0.25     (soft edge)

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec4 tint = COLOR;

    // Distance from center line in texture space (0 at center, 0.5 at edge)
    float d = abs(UV.y - 0.5);

    // band/2 because UV.y runs 0..1; half-distance from center
    float half_band = band * 0.5;

    // Smooth alpha: 1 in center, fades out toward edges
    float a = 1.0 - smoothstep(half_band, half_band + feather, d);

    // Keep lane texture detail but tint by team color so contested lanes can
    // clearly show both sides (yellow/green/etc.) using sprite.modulate.
    float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 recolor = tint.rgb * mix(0.35, 1.0, lum);
    COLOR = vec4(recolor, c.a * a * tint.a);
}
