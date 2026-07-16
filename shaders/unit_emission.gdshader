shader_type canvas_item;
render_mode blend_add, unshaded;

// These clipping uniforms intentionally mirror BeeClip.gdshader so the
// renderer can drive the base and emission passes from the same presentation
// state without inferring anything from pixels.
uniform float cut : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cut_dir = vec2(1.0, 0.0);
uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float key_threshold = 0.28;
uniform float key_softness = 0.10;
uniform float key_enabled = 0.0;
uniform float source_reveal_enabled = 0.0;
uniform float source_reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec2 source_reveal_dir = vec2(1.0, 0.0);
uniform float source_reveal_softness : hint_range(0.001, 0.30) = 0.045;

uniform float emission_strength : hint_range(0.0, 4.0) = 0.62;
uniform float emission_luma_floor : hint_range(0.0, 1.0) = 0.24;
uniform float emission_luma_hot : hint_range(0.0, 1.0) = 0.92;
uniform float hot_white_mix : hint_range(0.0, 1.0) = 0.12;
uniform vec2 abdomen_center = vec2(0.5, 0.53);
uniform vec2 abdomen_radius = vec2(0.20, 0.30);
uniform float abdomen_boost : hint_range(0.0, 2.0) = 0.32;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.05;
uniform float pulse_speed = 4.8;
uniform float pulse_phase = 0.0;

float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	vec2 safe_radius = max(radius, vec2(0.0001));
	vec2 delta = (uv - center) / safe_radius;
	return 1.0 - smoothstep(0.76, 1.0, length(delta));
}

void fragment() {
	vec4 canvas_tint = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	if (key_enabled > 0.5) {
		float key_distance = distance(tex.rgb, key_color.rgb);
		alpha *= smoothstep(
			key_threshold - key_softness,
			key_threshold + key_softness,
			key_distance
		);
	}

	vec2 local_p = (UV - vec2(0.5)) * 2.0;
	vec2 safe_cut_dir = cut_dir;
	if (length(safe_cut_dir) < 0.0001) {
		safe_cut_dir = vec2(1.0, 0.0);
	} else {
		safe_cut_dir = normalize(safe_cut_dir);
	}
	float cut_projection = dot(local_p, safe_cut_dir);
	float cut_threshold = mix(1.0, -1.0, clamp(cut, 0.0, 1.0));
	float visible = 1.0 - step(cut_threshold, cut_projection);

	if (source_reveal_enabled > 0.5) {
		vec2 safe_reveal_dir = source_reveal_dir;
		if (length(safe_reveal_dir) < 0.0001) {
			safe_reveal_dir = vec2(1.0, 0.0);
		} else {
			safe_reveal_dir = normalize(safe_reveal_dir);
		}
		float reveal_projection = dot(local_p, safe_reveal_dir);
		float reveal_threshold = mix(0.94, -1.08, clamp(source_reveal, 0.0, 1.0));
		visible *= smoothstep(
			reveal_threshold - source_reveal_softness,
			reveal_threshold + source_reveal_softness,
			reveal_projection
		);
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float luminous = smoothstep(emission_luma_floor, emission_luma_hot, luma);
	float abdomen = ellipse_mask(UV, abdomen_center, abdomen_radius);
	float emission_mask = alpha * luminous * (1.0 + abdomen * abdomen_boost) * visible;
	float hot = clamp(pow(luminous, 1.65) * hot_white_mix, 0.0, 1.0);
	vec3 emission_color = mix(canvas_tint.rgb, vec3(1.0), hot);
	float pulse = 1.0 + sin((TIME * pulse_speed) + pulse_phase) * pulse_strength;

	// Alpha never extends beyond the source texture. This is an additive
	// self-emission pass, not an enlarged outline or sampled halo.
	COLOR = vec4(
		emission_color * emission_strength * max(pulse, 0.0),
		clamp(emission_mask * canvas_tint.a, 0.0, 1.0)
	);
}
