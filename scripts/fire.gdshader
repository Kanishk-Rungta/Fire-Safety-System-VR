shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float strength : hint_range(0.0,1.0) = 0.5;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV; float n=noise(vec2(p.x*8.0,p.y*5.0+TIME*3.0));
	float body=clamp((1.0-abs(p.x-0.5)*2.0)*(1.0-p.y)+n*0.35-p.y*0.3,0.0,1.0);
	ALBEDO=mix(vec3(1.0,0.12,0.01),vec3(1.0,0.85,0.12),body);
	ALPHA=body*(0.35+strength*0.65);
}
