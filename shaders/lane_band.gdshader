shader_type canvas_item;

uniform float band = 0.18;   // 0.05..0.35  (thickness of visible center)
uniform float feather = 0.10; // 0..0.25     (soft edge)
uniform float team_saturation = 1.35;
uniform float lane_brightness = 1.55;
uniform float highlight_boost = 0.85;
uniform float glow_boost = 0.55;
uniform float surface_variation = 0.12;
uniform float satin_lift = 0.06;
uniform float endpoint_taper_fraction = 0.15;
uniform float endpoint_width_scale = 0.75;
uniform float ink_luma_floor = 0.20;
uniform float ink_luma_full = 0.52;
uniform float ink_chroma_floor = 0.10;
uniform float ink_chroma_full = 0.30;
uniform float lane_u_start = 0.0;
uniform float lane_u_end = 1.0;

varying float lane_u;

void vertex() {
    // Sprite2D lane pieces are simple quads. Mark their left/right vertices and
    // interpolate the canonical full-lane position across each visible piece.
    float piece_u = step(0.0, VERTEX.x);
    lane_u = mix(lane_u_start, lane_u_end, piece_u);
}

void fragment() {
    // Narrow only near the two hive sockets. lane_u is canonical across the
    // complete lane, so contested splits and overlap gaps do not create tapers.
    float endpoint_distance = min(lane_u, 1.0 - lane_u);
    float endpoint_blend = smoothstep(0.0, endpoint_taper_fraction, endpoint_distance);
    float width_scale = mix(endpoint_width_scale, 1.0, endpoint_blend);

    // Resample the artwork itself into the tapered width. Merely shrinking the
    // outer alpha envelope is not visible when the source rails sit inside it.
    vec2 tapered_uv = vec2(UV.x, ((UV.y - 0.5) / width_scale) + 0.5);
    vec4 c = texture(TEXTURE, tapered_uv);
    vec4 tint = COLOR;

    // Distance from center line in resampled texture space.
    float d = abs(tapered_uv.y - 0.5);
    float half_band = band * 0.5;

    // Smooth alpha: 1 in center, fades out toward edges
    float a = 1.0 - smoothstep(half_band, half_band + feather, d);
    float source_bounds = 1.0 - smoothstep(0.495, 0.505, d);
    a *= source_bounds;

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
    // Treat the source luminance as shallow surface relief instead of emitted
    // light. The narrow tonal range reads as satin/eggshell at game scale.
    vec3 satin_team = mix(team, vec3(1.0), satin_lift);
    float source_tone = smoothstep(0.08, 0.92, lum);
    float diffuse_tone = 1.0 + ((source_tone - 0.5) * surface_variation);
    vec3 base = satin_team * lane_brightness * diffuse_tone;
    float highlight_mix = smoothstep(0.62, 0.98, lum) * highlight_boost;
    vec3 highlight_target = mix(satin_team, vec3(1.0), 0.10) * lane_brightness;
    vec3 satin_surface = mix(base, highlight_target, highlight_mix);
    float edge_glow = ink * (1.0 - smoothstep(0.42, 0.95, d));
    vec3 glow = team * edge_glow * glow_boost;
    vec3 recolor = satin_surface + glow;
    COLOR = vec4(recolor, c.a * a * ink * tint.a);
}
