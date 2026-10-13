shader_type spatial;
// Sidewalk / plaza paving in world space: square slabs with grout lines,
// colour variation and grime, plus optional snow and wetness.

uniform vec3 stone : source_color = vec3(0.45, 0.44, 0.42);
uniform float tile = 0.6;
uniform float wet = 0.0;
uniform float snow = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	vec2 g = p / tile;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float grout = 1.0 - step(0.05, f.x) * step(0.05, f.y);
	vec3 col = stone * (0.85 + hash(id) * 0.2) * (0.9 + noise(p * 2.0) * 0.2);
	col = mix(col, stone * 0.55, grout);
	float n = noise(p * 0.7);
	col *= 0.9 + n * 0.15;
	float rough = mix(0.85, 0.95, grout);
	rough = mix(rough, 0.5, wet);
	col *= 1.0 - wet * 0.25;
	float sn = snow * smoothstep(0.35, 0.55, n + noise(p * 3.0) * 0.3) * step(0.5, wnrm.y);
	col = mix(col, vec3(0.88, 0.9, 0.95), clamp(sn + snow * 0.5 * step(0.5, wnrm.y), 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = rough;
}
