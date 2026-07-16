shader_type canvas_item;
render_mode unshaded, blend_add;

uniform bool front_arc = true;
uniform vec4 shoulder_color : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform vec4 fringe_color : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float distance_to_ring = abs(radius - 0.72);

	// Keep the white-hot center several physical pixels wide at gameplay scale.
	// The prior sub-pixel core disappeared into the hive's existing warm glow.
	float fringe = 1.0 - smoothstep(0.045, 0.250, distance_to_ring);
	float shoulder = 1.0 - smoothstep(0.020, 0.145, distance_to_ring);
	float core = 1.0 - smoothstep(0.006, 0.060, distance_to_ring);

	float angle = atan(p.y, p.x);
	float phase_breaks = smoothstep(0.035, 0.170, abs(sin(angle * 4.0 + 0.35)));
	float reactor_phase = mix(0.58, 1.0, phase_breaks);
	shoulder *= mix(0.82, 1.0, reactor_phase);
	core *= reactor_phase;

	float front_mask = smoothstep(-0.065, 0.065, p.y);
	float arc_mask = front_arc ? front_mask : (1.0 - front_mask);

	vec3 color = fringe_color.rgb * fringe * 0.32;
	color += shoulder_color.rgb * shoulder * 0.88;
	color += vec3(1.0, 0.995, 0.97) * core * 1.62;

	float alpha = clamp((fringe * 0.32) + (shoulder * 0.76) + (core * 1.15), 0.0, 1.0);
	alpha *= arc_mask * opacity;
	COLOR = vec4(color, alpha);
}
