shader_type canvas_item;

// 0 = fully visible, 1 = fully clipped
uniform float cut : hint_range(0.0, 1.0) = 0.0;

// Sprite-local forward direction (normalized)
uniform vec2 cut_dir = vec2(1.0, 0.0);

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float key_threshold = 0.28;
uniform float key_softness = 0.10;
uniform float key_enabled = 0.0;

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

	// Clip the part that has "gone inside"
	if (proj > threshold) {
		col.a = 0.0;
	}

	COLOR = col;
}
