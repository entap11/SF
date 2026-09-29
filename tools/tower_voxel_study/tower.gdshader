shader_type canvas_item;
render_mode unshaded;
uniform vec4 team : source_color = vec4(1.0,0.824,0.0,1.0);
void fragment() {
	vec4 c=texture(TEXTURE,UV);
	// Same white-key thresholds as SpriteRegistry._ensure_alpha for towers.
	float distance_from_white=max(1.0-c.r,max(1.0-c.g,1.0-c.b));
	float alpha=clamp((distance_from_white-0.12)/0.16,0.0,1.0);
	float yellow=step(c.b*1.6+0.06,c.r)*step(c.b*1.2+0.03,c.g);
	vec3 color=mix(c.rgb,team.rgb*max(c.r,c.g),yellow*0.8);
	COLOR=vec4(color,c.a*alpha)*COLOR;
}
