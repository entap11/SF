shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float r=length((UV-0.5)*2.0);
	float a=(1.0-smoothstep(0.25,1.0,r))*COLOR.a;
	COLOR=vec4(0.008,0.012,0.017,a);
}
