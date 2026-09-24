shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 footprint = vec2(150.0);
uniform vec4 owner_color : source_color = vec4(1.0,0.77,0.08,1.0);
uniform float energy = 0.0;
uniform float burst = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float seed = 0.0;
uniform float motion = 1.0;
varying vec2 local;
void vertex(){local=VERTEX/footprint;}
float gaussian(float x){return exp(-x*x);}
void fragment(){
    vec2 p=local-vec2(0.0,0.14);
    vec3 hot=mix(owner_color.rgb,vec3(1.0,0.66,0.28),0.44);
    vec3 white=vec3(1.0,0.94,0.77);
    // Elliptical mouth sits on the crown; heat remains attached to the outlet.
    float mouth=length(vec2(p.x/0.19,p.y/0.047));
    float rim=gaussian((mouth-1.0)/0.13);
    float bloom=exp(-dot(p/vec2(0.24,0.09),p/vec2(0.24,0.09))*1.8);
    float height=0.145+0.12*burst;
    float u=clamp(-p.y/height,0.0,1.0);
    float gate=(1.0-smoothstep(-0.012,0.035,p.y))*(1.0-smoothstep(0.55,1.0,u));
    float bend=sin(phase*6.1+u*7.0+seed)*0.010*u*motion;
    float taper=mix(0.029,0.015,u);
    float split=0.09*(1.0-u*0.38);
    float jet=gaussian((p.x-bend-split)/taper)+gaussian((p.x+bend+split)/(taper*0.78));
    float vapor=gaussian((p.x-bend)/(0.065*(1.0-u*0.55)))*gate;
    float shimmer=0.89+0.11*sin(phase*8.0-u*10.0+seed)*motion;
    vec3 c=hot*(bloom*0.24+vapor*0.42)+white*rim*0.29;
    c+=(hot*jet*0.72+white*pow(jet*0.5,3.0)*0.43)*gate*shimmer;
    // Four fixed paths, tapering into soft embers. No random texture or TIME.
    for(int i=0;i<4;i++){
        float n=float(i);
        float t=clamp(progress*1.3-n*0.047,0.0,1.0);
        float side=mod(n,2.0)*2.0-1.0;
        vec2 ember=vec2(side*(0.032+t*(0.10+n*0.018)),-0.01-t*(0.16+n*0.025)+t*t*0.085);
        vec2 d=(p-ember)/vec2(0.0045,0.008);
        c+=white*exp(-dot(d,d))*burst*(1.0-t)*motion*0.74;
    }
    COLOR=vec4(c*energy,1.0);
}
