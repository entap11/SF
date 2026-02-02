shader_type canvas_item;

uniform vec4 from_color : source_color = vec4(1.0, 0.82, 0.0, 1.0); // yellow target
uniform vec4 to_color   : source_color = vec4(0.65, 0.25, 1.0, 1.0); // npc purple (override in code)
uniform float hue_thresh = 0.10;      // widen/narrow match
uniform float sat_min = 0.35;         // ignore low-sat grays
uniform float val_min = 0.35;         // ignore dark pixels
uniform float softness = 0.08;        // edge feather

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

    float m = hue_match * sat_gate * val_gate;

    // swap hue toward target but preserve original alpha + some brightness feel
    vec3 out_rgb = mix(tex.rgb, to_color.rgb, m);

    COLOR = vec4(out_rgb, tex.a);
}
