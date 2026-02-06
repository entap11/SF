shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform bool align_right = false;

void fragment() {
	float x = UV.x;
	bool inside = align_right ? (x >= 1.0 - fill_ratio) : (x <= fill_ratio);
	vec4 col = COLOR;
	if (!inside) {
		col.a = 0.0;
	}
	COLOR = col;
}
