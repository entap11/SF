shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 channel_mask = vec4(1.0, 0.0, 0.0, 0.0);
uniform float strength : hint_range(0.0, 4.0, 0.001) = 1.0;

void fragment() {
	float blob = texture(TEXTURE, UV).a;
	COLOR = channel_mask * blob * strength;
}
