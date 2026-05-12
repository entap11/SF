shader_type canvas_item;

uniform vec4 from_color : source_color = vec4(1.0, 0.82, 0.0, 1.0); // yellow target
uniform vec4 to_color   : source_color = vec4(0.65, 0.25, 1.0, 1.0); // npc purple (override in code)
uniform float hue_thresh = 0.10;      // widen/narrow match
uniform float sat_min = 0.35;         // ignore low-sat grays
uniform float val_min = 0.35;         // ignore dark pixels
uniform float softness = 0.08;        // edge feather
uniform float white_sat_max = 0.28;   // include bright neutral tower pixels
uniform float white_val_min = 0.58;
uniform float white_strength = 1.0;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 hsv = rgb2hsv(tex.rgb);
    vec3 from_hsv = rgb2hsv(from_color.rgb);

    float hue_dist = abs(hsv.x - from_hsv.x);
    hue_dist = min(hue_dist, 1.0 - hue_dist); // wraparound

    float hue_match = 1.0 - smoothstep(hue_thresh - softness, hue_thresh + softness, hue_dist);
    float sat_gate = smoothstep(sat_min, sat_min + softness, hsv.y);
    float val_gate = smoothstep(val_min, val_min + softness, hsv.z);

    float color_match = hue_match * sat_gate * val_gate;
    float white_sat_gate = 1.0 - smoothstep(white_sat_max - softness, white_sat_max + softness, hsv.y);
    float white_val_gate = smoothstep(white_val_min - softness, white_val_min + softness, hsv.z);
    float white_match = white_sat_gate * white_val_gate * white_strength;
    float m = clamp(max(color_match, white_match), 0.0, 1.0);

    // Recolor the projection/body while retaining source luminance detail.
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 recolor = to_color.rgb * mix(0.48, 1.18, lum);
    vec3 out_rgb = mix(tex.rgb, recolor, m);

    COLOR = vec4(out_rgb, tex.a);
}
