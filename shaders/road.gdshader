shader_type spatial;
// Asphalt road in world space: patched, worn asphalt with tyre tracks, a
// double centre line, dashed lane lines, solid edge lines and zebra
// crossings. `wet` adds puddles and gloss, `snow` adds slush at the edges.
// along_z rotates the layout for side streets.

uniform vec3 asphalt : source_color = vec3(0.1, 0.1, 0.11);
uniform vec3 line_color : source_color = vec3(0.85, 0.85, 0.8);
uniform vec3 center_color : source_color = vec3(0.95, 0.72, 0.2);
uniform float center = -1.0;
uniform float half_width = 5.5;
uniform int lanes = 2;
uniform bool along_z = false;
uniform float wet = 0.0;
uniform float snow = 0.0;
uniform float crossings[16];
uniform int crossing_count = 0;
uniform float crossing_half = 2.6;

varying vec3 wpos;

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
}

void fragment() {
	float a = along_z ? wpos.z : wpos.x;   // along the road
	float c = (along_z ? wpos.x : wpos.z) - center;  // across
	float ac = abs(c);
	float n1 = noise(wpos.xz * 0.35);
	float n2 = noise(wpos.xz * 3.1);
	float n3 = noise(wpos.xz * 14.0);
	vec3 col = asphalt * (0.8 + n1 * 0.3 + n3 * 0.15);
	// Patches of newer/older asphalt.
	float patch = step(0.68, noise(floor(wpos.xz * 0.5) * 0.37 + 0.5));
	col *= 1.0 - patch * 0.18;
	// Tyre tracks: darker, smoother bands in each lane.
	float lane_w = half_width / float(lanes);
	float lc = fract(ac / lane_w);
	float track = smoothstep(0.12, 0.0, abs(lc - 0.3)) + smoothstep(0.12, 0.0, abs(lc - 0.7));
	col *= 1.0 - track * 0.12;
	float rough = 0.8 - track * 0.1;

	float paint = 0.0;
	vec3 pc = line_color;
	// Double centre line.
	float cl = step(abs(ac - 0.12), 0.05);
	if (cl > 0.0) { paint = cl; pc = center_color; }
	// Dashed lane lines.
	for (int i = 1; i < lanes; i++) {
		float lx = float(i) * lane_w;
		paint = max(paint, step(abs(ac - lx), 0.06) * step(fract(a / 3.0), 0.45));
	}
	// Edge lines.
	paint = max(paint, step(abs(ac - (half_width - 0.35)), 0.06));
	// Zebra crossings and stop lines.
	for (int i = 0; i < crossing_count; i++) {
		float d = a - crossings[i];
		if (abs(d) < crossing_half && ac < half_width - 0.5) {
			paint = max(paint, step(0.5, fract(d * 1.4)) * step(abs(d), crossing_half - 0.4));
			pc = line_color;
		}
		paint = max(paint, step(abs(abs(d) - crossing_half - 0.1), 0.08) * step(ac, half_width - 0.5));
	}
	paint *= 0.75 + n3 * 0.35; // worn paint
	col = mix(col, pc, clamp(paint, 0.0, 1.0));
	rough = mix(rough, 0.6, paint);

	// Rain: puddles and gloss.
	float puddle = smoothstep(0.55, 0.65, noise(wpos.xz * 0.6 + 7.0)) * wet;
	col *= 1.0 - wet * 0.35;
	rough = mix(rough, 0.25, wet);
	rough = mix(rough, 0.02, puddle);
	col = mix(col, col * 0.6, puddle);

	// Snow and slush: piled at the edges, cleared in the tyre tracks.
	float sn = snow * clamp(smoothstep(half_width - 2.2, half_width - 0.3, ac) + (n2 * 0.7 + n1 * 0.5 - 0.6) - track * 0.6, 0.0, 1.0);
	col = mix(col, vec3(0.85, 0.87, 0.92), sn);
	rough = mix(rough, 0.7, sn);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
