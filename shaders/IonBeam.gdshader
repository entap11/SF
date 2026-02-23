shader_type canvas_item;
render_mode blend_add;

uniform float glow_strength : hint_range(0.0, 4.0) = 2.0;
uniform float speed : hint_range(0.0, 12.0) = 4.0;

void fragment() {
	float sweep = fract(UV.x * 8.0 - TIME * speed);
	float core = 1.0 - smoothstep(0.0, 0.22, abs(UV.y - 0.5));
	float flicker = 0.7 + 0.3 * sin(TIME * 30.0 + sweep * 6.28318);
	float alpha = core;
	vec3 col = vec3(glow_strength * flicker * core);
	COLOR = vec4(col, alpha);
}
