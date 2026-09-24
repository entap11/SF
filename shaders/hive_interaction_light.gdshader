shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 footprint = vec2(100.0);
uniform vec4 owner_color : source_color = vec4(1.0);
uniform float selection = 0.0;
uniform float capture_energy = 0.0;
uniform float capture_progress = 0.0;
uniform float capture_travel = 1.0;
varying vec2 local;

void vertex() { local = VERTEX / footprint; }
float gaussian(float x) { return exp(-x * x); }

void fragment() {
	vec3 ivory = vec3(1.0, 0.965, 0.86);
	// Four short ground brackets close onto the real skirt and stay steady.
	// White selection stays distinct from team color and amber pressure vents.
	vec2 base = local - vec2(0.0, 0.315);
	vec2 radii = vec2(0.465, 0.105) * mix(1.08, 1.0, selection);
	vec2 q = base / radii;
	float edge = length(q) - 1.0;
	float corners = smoothstep(0.24, 0.42, abs(q.x)) * (1.0 - smoothstep(0.86, 0.97, abs(q.x)));
	float brackets = gaussian(edge / 0.025) * corners;
	float shoulder = gaussian(edge / 0.070) * corners;
	// Rear arcs only show beyond the body, never through the shell.
	float front = smoothstep(-0.02, 0.015, base.y);
	float exposed = max(front, smoothstep(0.38, 0.44, abs(local.x)));
	vec3 light = ivory * selection * (brackets * 0.90 + shoulder * 0.16) * exposed;
	if (capture_energy > 0.001) {
		// One fitted front sweep seats the new owner; no expanding shockwave.
		float height = mix(0.28, -0.28, capture_progress);
		float rx = mix(0.40, 0.225, capture_progress);
		float ry = mix(0.075, 0.045, capture_progress);
		vec2 sweep = vec2(local.x / rx, (local.y - height) / ry);
		float distance_to_seam = (length(sweep) - 1.0) * ry;
		float facing = smoothstep(-0.12, 0.12, sweep.y);
		float beam = gaussian(distance_to_seam / 0.005);
		float bloom = gaussian(distance_to_seam / 0.018);
		vec3 tint = mix(owner_color.rgb, ivory, 0.22);
		light += (ivory * beam * 0.66 + tint * bloom * 0.30) * facing * capture_energy * capture_travel;
		// A brief team-colored contact seal also works without spatial motion.
		float seal = gaussian(edge / 0.040);
		light += tint * seal * capture_energy * 0.55 * exposed;
	}
	COLOR = vec4(light, 1.0) * COLOR;
}
