shader_type canvas_item;
render_mode unshaded;
uniform vec2 quad_origin;
uniform vec2 quad_size;
varying vec2 surface_uv;
void vertex() { surface_uv=(VERTEX-quad_origin)/quad_size; }
uniform vec4 owner_color : source_color = vec4(1.0,0.72,0.16,1.0);
uniform float energy=0.0;
uniform float arrival=0.0;
uniform float radius_scale=1.0;
void fragment(){
    vec2 p=(surface_uv-vec2(0.5))*2.0;
    float r=length(p);
    float shadow=exp(-r*r*5.5)*0.73;
    float glow=exp(-r*r*4.5)*energy*0.28;
    float rim=exp(-pow((r-(0.44+arrival*0.18))/0.028,2.0))*energy*0.065;
    float a=clamp(shadow+glow+rim,0.0,0.93);
    vec3 c=owner_color.rgb*(glow+rim);
    COLOR=vec4(c/max(a,0.001),a);
}
