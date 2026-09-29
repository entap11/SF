shader_type canvas_item;
render_mode unshaded;
uniform vec4 team : source_color = vec4(1.0,0.82,0.0,1.0);
void fragment() {
	vec4 c=texture(TEXTURE,UV);
	float keyed=smoothstep(0.08,0.15,distance(c.rgb,vec3(1,0,1)));
	float yellow=step(c.b*1.4+0.05,c.r)*step(c.b*1.3+0.03,c.g);
	float luma=max(c.r,max(c.g,c.b));
	vec3 recolored=mix(c.rgb,team.rgb*(0.32+luma*0.8),yellow*0.90);
	COLOR=vec4(recolored,c.a*keyed)*COLOR;
}
