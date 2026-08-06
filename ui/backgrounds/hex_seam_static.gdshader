shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D static_texture : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	COLOR = texture(static_texture, UV) * COLOR;
}
