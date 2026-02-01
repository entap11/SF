shader_type canvas_item;

uniform float band = 0.18;   // 0.05..0.35  (thickness of visible center)
uniform float feather = 0.10; // 0..0.25     (soft edge)

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    // Distance from center line in texture space (0 at center, 0.5 at edge)
    float d = abs(UV.y - 0.5);

    // band/2 because UV.y runs 0..1; half-distance from center
    float half_band = band * 0.5;

    // Smooth alpha: 1 in center, fades out toward edges
    float a = 1.0 - smoothstep(half_band, half_band + feather, d);

    COLOR = vec4(c.rgb, c.a * a);
}
