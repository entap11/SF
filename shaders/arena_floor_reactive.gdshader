shader_type canvas_item;
render_mode unshaded;

uniform sampler2D influence_tex : source_color;
uniform sampler2D base_floor_tex : source_color;
uniform sampler2D noise_tex : source_color;

uniform bool use_base_floor_tex = true;
uniform bool use_noise_tex = false;

uniform vec4 player_color_0 : source_color = vec4(0.95, 0.85, 0.20, 1.0);
uniform vec4 player_color_1 : source_color = vec4(0.90, 0.22, 0.22, 1.0);
uniform vec4 player_color_2 : source_color = vec4(0.20, 0.62, 0.26, 1.0);
uniform vec4 player_color_3 : source_color = vec4(0.22, 0.52, 0.95, 1.0);

uniform float maturity : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float initial_maturity_floor : hint_range(0.0, 1.0, 0.001) = 0.18;
uniform float neutral_floor_strength : hint_range(0.0, 2.0, 0.001) = 0.92;
uniform float noise_strength : hint_range(0.0, 1.0, 0.001) = 0.08;
uniform float noise_scroll_speed : hint_range(0.0, 2.0, 0.001) = 0.04;
uniform float edge_glow_strength : hint_range(0.0, 2.0, 0.001) = 0.22;
uniform float edge_glow_threshold : hint_range(0.0, 1.0, 0.001) = 0.34;
uniform float circuit_emphasis : hint_range(0.0, 1.0, 0.001) = 0.75;
uniform float circuit_threshold : hint_range(0.0, 1.0, 0.001) = 0.60;
uniform float circuit_softness : hint_range(0.001, 1.0, 0.001) = 0.22;
uniform float circuit_edge_emphasis : hint_range(0.0, 1.0, 0.001) = 0.85;
uniform float circuit_edge_threshold : hint_range(0.0, 1.0, 0.001) = 0.045;
uniform float circuit_edge_softness : hint_range(0.001, 1.0, 0.001) = 0.045;
uniform float circuit_background_leak : hint_range(0.0, 1.0, 0.001) = 0.08;
uniform float territory_threshold : hint_range(0.0, 1.0, 0.001) = 0.18;
uniform float territory_softness : hint_range(0.001, 1.0, 0.001) = 0.24;
uniform float dominance_threshold : hint_range(0.0, 1.0, 0.001) = 0.48;
uniform float wire_base_strength : hint_range(0.0, 2.0, 0.001) = 0.22;
uniform float wire_pulse_strength : hint_range(0.0, 2.0, 0.001) = 0.45;
uniform float wire_pulse_speed : hint_range(0.0, 10.0, 0.001) = 2.2;
uniform float wire_phase_scale : hint_range(0.0, 20.0, 0.001) = 8.0;
uniform float max_influence_per_pixel : hint_range(0.01, 8.0, 0.01) = 1.2;
uniform int blend_mode = 0; // 0=weighted, 1=dominant
uniform bool debug_influence_preview = false;
uniform bool debug_force_magenta = false;

void fragment() {
	if (debug_force_magenta) {
		COLOR = vec4(1.0, 0.0, 1.0, 1.0);
	} else {
	vec4 influence = texture(influence_tex, UV);
	float total_raw = max(0.0, influence.r + influence.g + influence.b + influence.a);
	float total = clamp(total_raw / max(max_influence_per_pixel, 0.0001), 0.0, 1.0);

	vec3 weighted_mix = vec3(0.0);
	if (total_raw > 0.0001) {
		vec4 w = influence / total_raw;
		weighted_mix += player_color_0.rgb * w.r;
		weighted_mix += player_color_1.rgb * w.g;
		weighted_mix += player_color_2.rgb * w.b;
		weighted_mix += player_color_3.rgb * w.a;
	}

	vec4 channels = vec4(influence.r, influence.g, influence.b, influence.a);
	float max_channel = max(max(channels.r, channels.g), max(channels.b, channels.a));
	vec3 dominant_mix = player_color_0.rgb;
	if (max_channel == channels.g) {
		dominant_mix = player_color_1.rgb;
	}
	if (max_channel == channels.b) {
		dominant_mix = player_color_2.rgb;
	}
	if (max_channel == channels.a) {
		dominant_mix = player_color_3.rgb;
	}

	vec3 player_mix = weighted_mix;
	if (blend_mode == 1) {
		player_mix = dominant_mix;
	}
	if (debug_influence_preview) {
		float hard = clamp(total_raw, 0.0, 1.0);
		COLOR = vec4(player_mix * hard, 1.0);
	} else {
		vec4 base_sample = texture(TEXTURE, UV);
		if (use_base_floor_tex) {
			base_sample = texture(base_floor_tex, UV);
		}
		vec3 base_col = base_sample.rgb;
		vec2 px = TEXTURE_PIXEL_SIZE;
		float luma = dot(base_col, vec3(0.2126, 0.7152, 0.0722));
		vec3 s_xp = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb;
		vec3 s_xm = texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb;
		vec3 s_yp = texture(TEXTURE, UV + vec2(0.0, px.y)).rgb;
		vec3 s_ym = texture(TEXTURE, UV - vec2(0.0, px.y)).rgb;
		if (use_base_floor_tex) {
			s_xp = texture(base_floor_tex, UV + vec2(px.x, 0.0)).rgb;
			s_xm = texture(base_floor_tex, UV - vec2(px.x, 0.0)).rgb;
			s_yp = texture(base_floor_tex, UV + vec2(0.0, px.y)).rgb;
			s_ym = texture(base_floor_tex, UV - vec2(0.0, px.y)).rgb;
		}
		float l_xp = dot(s_xp, vec3(0.2126, 0.7152, 0.0722));
		float l_xm = dot(s_xm, vec3(0.2126, 0.7152, 0.0722));
		float l_yp = dot(s_yp, vec3(0.2126, 0.7152, 0.0722));
		float l_ym = dot(s_ym, vec3(0.2126, 0.7152, 0.0722));
		float edge_energy = (abs(luma - l_xp) + abs(luma - l_xm) + abs(luma - l_yp) + abs(luma - l_ym)) * 0.25;

		float n = 0.0;
		if (use_noise_tex) {
			vec2 n_uv = UV + vec2(TIME * noise_scroll_speed, TIME * noise_scroll_speed * 0.71);
			n = texture(noise_tex, n_uv).r * 2.0 - 1.0;
		}

		float raw_influence = clamp(total + n * noise_strength, 0.0, 1.0);
		float influence_presence = pow(raw_influence, 0.58);
		float maturity_mix = mix(clamp(initial_maturity_floor, 0.0, 1.0), 1.0, clamp(maturity, 0.0, 1.0));
		float bright_mask = smoothstep(circuit_threshold, circuit_threshold + max(circuit_softness, 0.001), luma);
		float edge_mask = smoothstep(circuit_edge_threshold, circuit_edge_threshold + max(circuit_edge_softness, 0.001), edge_energy);
		float conduit_mask = max(edge_mask, bright_mask * 0.25);
		conduit_mask = mix(conduit_mask, max(conduit_mask, edge_mask), clamp(circuit_edge_emphasis, 0.0, 1.0));
		float conduit_weight = mix(clamp(circuit_background_leak, 0.0, 1.0), 1.0, clamp(conduit_mask, 0.0, 1.0));
		float circuit_weight = mix(1.0, conduit_weight, clamp(circuit_emphasis, 0.0, 1.0));
		float territory_mask = smoothstep(
			territory_threshold,
			territory_threshold + max(territory_softness, 0.001),
			influence_presence
		);
		float dominance = 0.0;
		if (total_raw > 0.0001) {
			dominance = max_channel / total_raw;
		}
		float dominance_mask = smoothstep(dominance_threshold, 1.0, dominance);
		float owned_area = territory_mask * dominance_mask * maturity_mix;
		float wire_mask = clamp(conduit_mask * circuit_weight, 0.0, 1.0);
		float pulse_wave = 0.5 + 0.5 * sin(TIME * wire_pulse_speed + (UV.x + UV.y) * wire_phase_scale);
		float wire_strength = owned_area * wire_mask * (wire_base_strength + wire_pulse_strength * pulse_wave);
		float base_tint_strength = owned_area * mix(0.05, 0.16, wire_mask);

		vec3 neutral_col = base_col * neutral_floor_strength;
		vec3 out_col = neutral_col + player_mix * base_tint_strength;
		out_col += player_mix * wire_strength;

		float glow = smoothstep(edge_glow_threshold, edge_glow_threshold + 0.08, influence_presence);
		glow *= edge_glow_strength * owned_area;
		out_col += player_mix * glow;

		COLOR = vec4(out_col, base_sample.a);
	}
	}
}
