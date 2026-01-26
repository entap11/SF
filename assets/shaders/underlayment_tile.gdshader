shader_type canvas_item;

uniform float tile_scale = 10.0;

void fragment() {
	vec2 uv = fract(UV * tile_scale);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
