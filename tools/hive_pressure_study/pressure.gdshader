shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 footprint = vec2(150.0);
uniform vec4 owner_color : source_color = vec4(1.0,0.77,0.08,1.0);
uniform float energy = 0.0;
uniform float burst = 0.0;
uniform float pulse = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float motion = 1.0;
varying vec2 local;
void vertex(){local=VERTEX/footprint;}
float gaussian(float x){return exp(-x*x);}
void fragment(){
    vec2 p=local-vec2(0.0,0.14);
    vec3 hot=mix(owner_color.rgb,vec3(1.0,0.42,0.055),0.72);
    vec3 white=vec3(1.0,0.95,0.82);
    // Elliptical mouth sits on the crown; heat remains attached to the outlet.
    float mouth=length(vec2(p.x/0.225,p.y/0.056));
    float rim=gaussian((mouth-1.0-pulse*0.045)/0.16);
    float bloom=exp(-dot(p/vec2(0.285,0.095),p/vec2(0.285,0.095))*1.8);
    float height=0.28+0.09*burst+0.035*pulse;
    float u=clamp(-p.y/height,0.0,1.0);
    float gate=(1.0-smoothstep(-0.012,0.035,p.y))*(1.0-smoothstep(0.62,1.0,u));
    float bend=sin(phase*6.1+u*7.0+seed)*0.016*u*motion;
    float shimmer=0.93+0.07*sin(phase*8.0-u*10.0+seed)*motion;
    float taper=mix(0.054,0.022,u)*shimmer;
    float split=0.13+0.115*u;
    float jet=gaussian((p.x-bend-split)/taper)+gaussian((p.x+bend+split)/(taper*0.78))*(1.0-smoothstep(0.54,0.92,u));
    float vapor=gaussian((p.x-bend)/(0.11*(1.0-u*0.55)))*gate;
    // The taller, splayed vents frame the number instead of bleaching its centre.
    float badge_gutter=1.0-(1.0-smoothstep(0.10,0.18,abs(p.x)))*(1.0-smoothstep(-0.12,-0.065,p.y));
    vec3 c=hot*(bloom*0.32+vapor*0.52)+white*rim*0.56;
    c+=(hot*jet*0.82+white*pow(jet*0.5,3.0)*0.85)*gate*shimmer;
    // Four fixed paths, tapering into soft embers. No random texture or TIME.
    for(int i=0;i<4;i++){
        float n=float(i);
        float t=clamp(progress*1.3-n*0.047,0.0,1.0);
        float side=mod(n,2.0)*2.0-1.0;
        vec2 ember=vec2(side*(0.10+t*(0.16+n*0.025)),-0.01-t*(0.29+n*0.020)+t*t*0.085);
        vec2 d=(p-ember)/vec2(0.010,0.015);
        c+=white*exp(-dot(d,d))*burst*(1.0-t)*motion*1.10;
    }
    COLOR=vec4(c*energy*badge_gutter,1.0);
}
