shader_type spatial;
// Procedural office tower: a window grid with random lit windows, floor bands,
// and soot/blackout that grows with `damage`. Works on a BoxMesh in local units.

uniform vec4 wall_color : source_color = vec4(0.32, 0.34, 0.38, 1.0);
uniform vec4 trim_color : source_color = vec4(0.2, 0.21, 0.24, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform vec4 glass_color : source_color = vec4(0.08, 0.11, 0.16, 1.0);
uniform vec2 cell = vec2(1.6, 2.0);
uniform float lit_ratio = 0.35;
uniform float seed = 0.0;
uniform float damage = 0.0;
uniform float emission_strength = 2.5;

varying vec3 lpos;
varying vec3 lnrm;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	vec3 n = abs(lnrm);
	if (n.y > 0.5) {
		ALBEDO = trim_color.rgb * 0.7;
		ROUGHNESS = 0.9;
	} else {
		vec2 uv = n.x > 0.5 ? vec2(lpos.z, lpos.y) : vec2(lpos.x, lpos.y);
		vec2 g = uv / cell;
		vec2 id = floor(g);
		vec2 f = fract(g);
		float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.2, f.y) * step(f.y, 0.8);
		float band = step(0.9, f.y);
		float r = hash(id + (n.x > 0.5 ? vec2(37.0, 11.0) : vec2(0.0)));
		float lit = step(1.0 - lit_ratio, r) * step(damage * 1.3, hash(id + 7.3));
		float soot = damage * smoothstep(0.25, 1.0, hash(floor(uv * 0.5) + 3.1));
		vec3 wall = mix(wall_color.rgb, trim_color.rgb, band);
		vec3 glass = mix(glass_color.rgb, lit_color.rgb * 0.6, lit);
		vec3 col = mix(wall, glass, win);
		col *= 1.0 - soot * 0.75;
		ALBEDO = col;
		ROUGHNESS = mix(0.85, 0.06, win);
		METALLIC = win * (1.0 - lit) * 0.7;
		EMISSION = lit_color.rgb * lit * win * emission_strength * (1.0 - soot);
	}
}
