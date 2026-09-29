shader_type canvas_item;
render_mode unshaded;

varying float face_visibility;
varying float face_light;
varying vec2 face_uv;
varying vec4 block_color;
varying float hot;

mat3 rotation(vec3 a) {
	vec3 c = cos(a), s = sin(a);
	mat3 rx = mat3(vec3(1,0,0), vec3(0,c.x,s.x), vec3(0,-s.x,c.x));
	mat3 ry = mat3(vec3(c.y,0,-s.y), vec3(0,1,0), vec3(s.y,0,c.y));
	mat3 rz = mat3(vec3(c.z,s.z,0), vec3(-s.z,c.z,0), vec3(0,0,1));
	return rz * ry * rx;
}

void vertex() {
	// UV.x stores depth, UV.y stores face ID. No TIME or gameplay state.
	vec3 p = vec3(VERTEX, UV.x);
	int face = int(round(UV.y));
	vec3 n = vec3(0,0,1);
	if (face == 0) { n=vec3(1,0,0); face_uv=p.yz; }
	if (face == 1) { n=vec3(-1,0,0); face_uv=p.yz; }
	if (face == 2) { n=vec3(0,1,0); face_uv=p.xz; }
	if (face == 3) { n=vec3(0,-1,0); face_uv=p.xz; }
	if (face == 4) { n=vec3(0,0,1); face_uv=p.xy; }
	if (face == 5) { n=vec3(0,0,-1); face_uv=p.xy; }
	mat3 r = rotation(INSTANCE_CUSTOM.xyz);
	p = r * p;
	n = r * n;
	vec3 eye = normalize(vec3(0,-0.65,0.76));
	vec3 light = normalize(vec3(-0.45,-0.65,1.0));
	face_visibility = dot(n,eye);
	float specular = pow(max(dot(n,normalize(light+eye)),0.0),22.0);
	face_light = 0.42 + 0.68 * max(dot(n,light),0.0) + 0.38 * specular;
	VERTEX = vec2(p.x, p.y * 0.76 - p.z * 0.65);
	block_color=COLOR;
	hot=INSTANCE_CUSTOM.w;
}

void fragment() {
	if (face_visibility <= 0.0) { discard; }
	float edge = smoothstep(0.435,0.495,max(abs(face_uv.x),abs(face_uv.y)));
	vec3 rgb = block_color.rgb * face_light;
	rgb = mix(rgb,rgb*0.64+vec3(0.025),edge*0.68);
	rgb += hot * vec3(0.72,0.84,0.92);
	COLOR=vec4(rgb,block_color.a);
}
