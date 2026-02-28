shader_type canvas_item;

// 0 = fully visible, 1 = fully clipped
uniform float cut : hint_range(0.0, 1.0) = 0.0;

// Sprite-local forward direction (normalized)
uniform vec2 cut_dir = vec2(1.0, 0.0);

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float key_threshold = 0.28;
uniform float key_softness = 0.10;
uniform float key_enabled = 0.0;
uniform float ion_enabled = 1.0;
uniform float ion_strength : hint_range(0.0, 3.0) = 1.05;
uniform float ion_band : hint_range(0.001, 0.40) = 0.130;
uniform float ion_softness : hint_range(0.0, 0.25) = 0.030;
uniform float ion_center_power : hint_range(0.2, 4.0) = 1.25;
uniform float ion_edge_floor : hint_range(0.0, 1.0) = 0.28;
uniform vec4 ion_core_color : source_color = vec4(1.0, 0.97, 0.95, 1.0);
uniform vec4 ion_edge_color : source_color = vec4(1.0, 0.80, 0.76, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	if (key_enabled > 0.5) {
		float d = distance(tex.rgb, key_color.rgb);
		alpha *= smoothstep(key_threshold - key_softness, key_threshold + key_softness, d);
	}
	vec4 col = vec4(tex.rgb, alpha) * COLOR;

	// Centered UV in approx [-1..1]
	vec2 p = (UV - vec2(0.5)) * 2.0;
	vec2 dir = cut_dir;
	float dir_len = length(dir);
	if (dir_len < 0.0001) {
		dir = vec2(1.0, 0.0);
	} else {
		dir = dir / dir_len;
	}
	float proj = dot(p, dir); // approx -1..+1 along forward axis

	// cut=0 => threshold=+1 (clip nothing), cut=1 => threshold=-1 (clip everything)
	float threshold = mix(1.0, -1.0, clamp(cut, 0.0, 1.0));
	float clipped = step(threshold, proj); // 1 when this fragment is past clip plane
	float visible = 1.0 - clipped;

	if (ion_enabled > 0.5) {
		// Distance on the still-visible side to the clip plane.
		float dist_to_cut = max(0.0, threshold - proj);
		float rim = 1.0 - smoothstep(ion_band, ion_band + ion_softness, dist_to_cut);

		// Brighter in the center of bee thickness; dimmer toward edges.
		vec2 perp = vec2(-dir.y, dir.x);
		float lateral = abs(dot(p, perp));
		float center = pow(clamp(1.0 - lateral, 0.0, 1.0), ion_center_power);
		float center_weight = mix(ion_edge_floor, 1.0, center);

		// Subtle laser-cleaning flicker.
		float flicker = 0.94 + 0.06 * sin(TIME * 44.0 + lateral * 21.0 + proj * 9.0);
		vec3 ion_rgb = mix(ion_edge_color.rgb, ion_core_color.rgb, center);
		float surface_mask = clamp(col.a, 0.0, 1.0);
		float ion_alpha = visible * rim * surface_mask * ion_strength * center_weight * flicker;
		col.rgb += ion_rgb * ion_alpha;
	}

	// Clip the part that has "gone inside"
	if (clipped > 0.5) {
		col.a = 0.0;
	}

	COLOR = col;
}
