shader_type canvas_item;
render_mode unshaded;
uniform vec2 quad_origin;
uniform vec2 quad_size;
varying vec2 surface_uv;
void vertex() { surface_uv=(VERTEX-quad_origin)/quad_size; }

// All motion is supplied by the presenter. No TIME, random source or screen reads.
uniform sampler2D before_tex : source_color, filter_linear_mipmap;
uniform sampler2D after_tex : source_color, filter_linear_mipmap;
uniform vec2 before_size = vec2(0.70, 0.78);
uniform vec2 after_size = vec2(0.78, 0.90);
uniform vec4 owner_color : source_color = vec4(1.0, 0.75, 0.12, 1.0);
uniform float reveal = 0.0;
uniform float charge = 0.0;
uniform float sweep = 1.0;
uniform float band_energy = 0.0;
uniform float settle = 0.0;
uniform float direction = 1.0;
uniform float reduced = 0.0;
uniform float body_scale = 1.0;
uniform vec2 before_center = vec2(0.0);
uniform vec2 after_center = vec2(0.0);
uniform vec4 before_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 after_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 before_flip = vec2(0.0);
uniform vec2 after_flip = vec2(0.0);
uniform float neutral = 0.0;
uniform float selected_hot = 0.0;
uniform vec4 selected_hot_color : source_color = vec4(1.0);
uniform float selected_metal_lift = 0.0;
uniform float selected_hot_edge = 0.0;
uniform float glow_strength = 0.8;
uniform float additive_glow = 0.18;
uniform float white_strength = 0.95;
uniform float crown_preserve = 1.0;
uniform float before_key_enabled = 0.0;
uniform float after_key_enabled = 0.0;
uniform float surface_opacity = 1.0;
uniform float global_alpha = 1.0;
uniform vec4 key_color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float key_threshold = 0.035;
uniform float key_softness = 0.018;

vec4 source_sample(sampler2D tex, vec2 p, vec2 sz, vec2 center, vec4 region, vec2 flip, float key_enabled) {
    float ground=center.y+sz.y*0.44;
    vec2 uv = vec2((p.x-center.x)/sz.x+0.5,(p.y-ground)/(sz.y*body_scale)+0.94);
    vec2 source_uv=mix(uv,vec2(1.0)-uv,flip);
    vec4 s = texture(tex,region.xy+clamp(source_uv,vec2(0.0),vec2(1.0))*region.zw);
    float bounds = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    s.a *= bounds;
    if(key_enabled>0.5) s.a*=smoothstep(key_threshold-key_softness,key_threshold+key_softness,distance(s.rgb,key_color.rgb));
    return s;
}

vec3 illuminate(vec4 s, vec2 uv, vec2 p) {
    float hi = max(s.r, max(s.g, s.b));
    float lo = min(s.r, min(s.g, s.b));
    float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
    float white = (1.0 - smoothstep(0.24, 0.40, (hi-lo)/max(hi,0.001))) * smoothstep(0.48,0.66,hi);
    float yellow = smoothstep(0.55,0.85,s.r)*smoothstep(0.45,0.80,s.g)*(1.0-smoothstep(0.10,0.30,s.b));
    float emissive = max(white * white_strength, yellow) * mix(1.0,smoothstep(0.27,0.39,uv.y),crown_preserve);
    vec3 base = mix(s.rgb, mix(vec3(lum), vec3(hi), 0.72) * mix(vec3(1.0),owner_color.rgb,0.78), emissive * 0.92);
    base += owner_color.rgb * hi * emissive * glow_strength * additive_glow;
    if(neutral>0.5) base=vec3(lum)*owner_color.rgb;
    float metal=(1.0-smoothstep(0.16,0.62,lum))*smoothstep(0.18,0.95,s.a);
    vec3 hot_metal=mix(base,mix(vec3(0.86,0.90,0.95),selected_hot_color.rgb,0.52),metal*selected_metal_lift);
    float hot_edge=smoothstep(0.30,0.98,hi)*metal;
    base=mix(base,hot_metal+selected_hot_color.rgb*hot_edge*selected_hot_edge,selected_hot);
    float core_gate = (1.0 - smoothstep(0.23,0.42,abs(uv.x-0.5))) * smoothstep(0.22,0.48,uv.y);
    base += mix(owner_color.rgb,vec3(1.0,0.95,0.81),0.32) * emissive * core_gate * charge * 0.35;
    float shell = (1.0-emissive) * smoothstep(0.06,0.28,lum);
    float scan = band_energy > 0.001 ? exp(-pow((p.y - sweep)/0.055,2.0)) : 0.0;
    base += mix(owner_color.rgb,vec3(1.0,0.96,0.86),0.62) * shell * scan * band_energy * 0.55;
    // A restrained cap glint travels once across real textured metal at seating.
    float cap = settle > 0.001 ? exp(-pow((uv.y-0.19)/0.115,2.0)) : 0.0;
    base += vec3(0.91,0.95,1.0)*cap*shell*settle*0.26;
    return base;
}

void fragment() {
    vec2 p = surface_uv - vec2(0.5);
    vec2 assembled_size=mix(before_size,after_size,reveal);
    vec2 center=mix(before_center,after_center,reveal);
    vec4 a = source_sample(before_tex,p,mix(assembled_size,before_size,reduced),mix(center,before_center,reduced),before_region,before_flip,before_key_enabled);
    vec4 b = source_sample(after_tex,p,mix(assembled_size,after_size,reduced),mix(center,after_center,reduced),after_region,after_flip,after_key_enabled);
    float mask = direction > 0.0 ? smoothstep(sweep-0.027,sweep+0.027,p.y) : 1.0-smoothstep(sweep-0.027,sweep+0.027,p.y);
    mask = mix(mask,reveal,reduced);
    if (reveal <= 0.0) { mask=0.0; }
    if (reveal >= 1.0) { mask=1.0; }
    float alpha = mix(a.a,b.a,mask);
    vec3 premul = mix(a.rgb*a.a,b.rgb*b.a,mask);
    vec2 material_uv=vec2((p.x-center.x)/assembled_size.x+0.5,
        (p.y-(center.y+assembled_size.y*0.44))/(assembled_size.y*body_scale)+0.94);
    vec3 base=illuminate(vec4(premul/max(alpha,0.0001),alpha),material_uv,p);
    premul=base*alpha;
    if(band_energy<=0.001) {
        COLOR=vec4(base,alpha*surface_opacity*global_alpha);
    } else {
    vec2 sz=mix(before_size,after_size,reveal);
    float ground=center.y+sz.y*0.44;
    float band_y=clamp(sweep,ground-sz.y*0.70,ground-sz.y*0.045);
    float height=clamp((ground-band_y)/sz.y,0.0,1.0);
    // The fitted elliptical section narrows from skirt to crown.
    float rx=sz.x*mix(0.405,0.288,smoothstep(0.0,0.87,height));
    float ry=rx*0.29;
    vec2 q=vec2((p.x-center.x)/max(rx,0.01),(p.y-band_y)/max(ry,0.01));
    float distance_to_band=abs(length(q)-1.0)*ry;
    float front=smoothstep(-0.15,0.25,q.y);
    float beam=exp(-pow(distance_to_band/0.0033,2.0));
    float shoulder=exp(-pow(distance_to_band/0.010,2.0));
    float halo=exp(-distance_to_band/0.024);
    float edge_weight=0.70+0.30*pow(abs(normalize(q+vec2(0.001)).x),4.0);
    float emission=band_energy*edge_weight*(1.0-smoothstep(0.79,1.0,reveal));
    float occlusion=mix(1.0-alpha,1.0,front);
    vec3 energy_color=mix(owner_color.rgb,vec3(1.0,0.91,0.70),0.40);
    vec3 glow=(vec3(1.0,0.97,0.86)*beam*1.12 + energy_color*shoulder*0.42 + energy_color*halo*0.075)*emission*occlusion;
    float glow_alpha=clamp((beam+shoulder*0.65+halo*0.18)*emission*occlusion,0.0,1.0);
    float out_alpha=alpha+(1.0-alpha)*glow_alpha;
    COLOR=vec4((premul+glow)/max(out_alpha,0.0001),out_alpha*surface_opacity*global_alpha);
    }
}
