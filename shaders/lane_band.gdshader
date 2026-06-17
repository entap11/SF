shader_type canvas_item;

uniform float band = 0.18;   // 0.05..0.35  (thickness of visible center)
uniform float feather = 0.10; // 0..0.25     (soft edge)
uniform float team_saturation = 1.35;
uniform float lane_brightness = 1.55;
uniform float highlight_boost = 0.85;
uniform float glow_boost = 0.55;
uniform float ink_luma_floor = 0.20;
uniform float ink_luma_full = 0.52;
uniform float ink_chroma_floor = 0.10;
uniform float ink_chroma_full = 0.30;
instance uniform float lane_tile_void_period = 1.0;
instance uniform float lane_tile_void_keep = 1.0;
instance uniform float lane_tile_void_phase = 0.0;
instance uniform float lane_tile_repeat_count = 1.0;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec4 tint = COLOR;

    // Distance from center line in texture space (0 at center, 0.5 at edge)
    float d = abs(UV.y - 0.5);

    // band/2 because UV.y runs 0..1; half-distance from center
    float half_band = band * 0.5;

    // Smooth alpha: 1 in center, fades out toward edges
    float a = 1.0 - smoothstep(half_band, half_band + feather, d);

    float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    float max_chan = max(c.r, max(c.g, c.b));
    float min_chan = min(c.r, min(c.g, c.b));
    float chroma = max_chan - min_chan;
    float bright_ink = smoothstep(ink_luma_floor, ink_luma_full, lum);
    float saturated_ink = smoothstep(ink_chroma_floor, ink_chroma_full, chroma) * smoothstep(0.12, 0.34, max_chan);
    float ink = clamp(max(bright_ink, saturated_ink), 0.0, 1.0);

    // Keep the rails/arrows from the source texture, but let the transparent
    // box interior drop away and recolor the remaining detail to the owning team.
    vec3 gray = vec3(dot(tint.rgb, vec3(0.299, 0.587, 0.114)));
    vec3 team = mix(gray, tint.rgb, team_saturation);
    vec3 base = team * mix(0.52, lane_brightness, smoothstep(0.08, 0.72, lum));
    vec3 highlights = mix(team, vec3(1.0), 0.35) * smoothstep(0.48, 0.96, lum) * highlight_boost;
    float edge_glow = ink * (1.0 - smoothstep(0.42, 0.95, d));
    vec3 glow = team * edge_glow * glow_boost;
    vec3 recolor = base + highlights + glow;
    float tile_mask = 1.0;
    if (lane_tile_void_period > 1.0 && lane_tile_void_keep < lane_tile_void_period) {
        float tile_x = floor(max(0.0, UV.x) * max(1.0, lane_tile_repeat_count) + lane_tile_void_phase);
        tile_mask = step(mod(tile_x, lane_tile_void_period), lane_tile_void_keep - 0.001);
    }
    COLOR = vec4(recolor, c.a * a * ink * tint.a * tile_mask);
}
