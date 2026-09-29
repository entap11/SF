extends RefCounted
## Pure presentation timing: seconds in, disposable visual parameters out.

static func sample(time: float, old_tier: int, new_tier: int, low_motion: bool=false) -> Dictionary:
    var up: bool=new_tier>old_tier
    var duration: float=0.66 if up else 0.49
    var t: float=maxf(0.0,time)
    if low_motion:
        return {"reveal":smoothstep(0.0,0.13,t),"charge":0.0,"band_energy":0.0,"settle":0.0,"body_scale":1.0,"ground":0.0,"done":t>=0.13}
    if old_tier==new_tier or t>=duration:
        return {"reveal":1.0,"charge":0.0,"band_energy":0.0,"settle":0.0,"body_scale":1.0,"ground":0.0,"done":true}
    var start: float=0.17 if up else 0.075
    var end: float=0.46 if up else 0.34
    var reveal_t: float=smoothstep(start,end,t)
    var charge_t: float=smoothstep(0.0,0.12 if up else 0.06,t)*(1.0-smoothstep(start,end+0.04,t))
    var band: float=smoothstep(start-0.025,start+0.028,t)*(1.0-smoothstep(end-0.015,end+0.055,t))
    var settle_t: float=clampf((t-end)/(duration-end),0.0,1.0)
    var compression: float=-0.018*charge_t if up else -0.007*charge_t
    var rebound: float=sin(settle_t*PI)*exp(-settle_t*2.4)*(0.023 if up else -0.010)
    return {"reveal":reveal_t,"charge":charge_t*(1.0 if up else 0.22),"band_energy":band*(1.0 if up else 0.48),"settle":sin(settle_t*PI),"body_scale":1.0+compression+rebound,"ground":(charge_t*0.40+band*0.58+sin(settle_t*PI)*0.40)*(1.0 if up else 0.40),"done":false}
