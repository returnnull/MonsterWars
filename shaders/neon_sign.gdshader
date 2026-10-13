shader_type spatial;
render_mode unshaded, cull_disabled;
// Neon sign / billboard on a unit quad, shared by every sign; the colour,
// seed, glyph cells and brightness are per-instance. Draws a lit border and
// blocky pseudo-glyphs (no real text), with an occasional flicker.

instance uniform vec4 sign_color : source_color = vec4(1.0, 0.2, 0.6, 1.0);
instance uniform float sign_seed = 0.0;
instance uniform vec2 cells = vec2(1.0, 4.0);
instance uniform float brightness = 2.0;

float hash(vec2 p) {
	p = fract(p * vec2(233.34, 851.73) + sign_seed);
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 c = sign_color.rgb;
	// Panel background: dark, tinted.
	// Night: dark panel lit by neon tubes. Day: a printed, coloured panel.
	float day = 1.0 - smoothstep(0.9, 1.6, brightness);
	vec3 col = mix(c * 0.08 + vec3(0.02), c * 0.75 + 0.05, day);
	// Border tube.
	vec2 e = min(uv, 1.0 - uv) * cells.yx / max(cells.x, cells.y) * 4.0;
	float border = 1.0 - smoothstep(0.03, 0.07, min(e.x, e.y));
	// Glyph grid: each cell is a 4x5 block glyph from the hash.
	vec2 g = uv * cells;
	vec2 cid = floor(g);
	vec2 f = fract(g);
	vec2 inner = (f - 0.14) / 0.72;
	float glyph = 0.0;
	if (inner.x > 0.0 && inner.x < 1.0 && inner.y > 0.0 && inner.y < 1.0) {
		vec2 px = floor(inner * vec2(4.0, 5.0));
		float on = step(0.45, hash(cid * 7.0 + px));
		// Make strokes connect a little: always light the centre column/row sometimes.
		on = max(on, step(0.7, hash(cid + 3.0)) * step(abs(px.x - 1.5), 0.6));
		vec2 pf = fract(inner * vec2(4.0, 5.0));
		glyph = on * step(0.1, pf.x) * step(pf.x, 0.9) * step(0.1, pf.y) * step(pf.y, 0.9);
	}
	// Alternate glyph colour per sign.
	vec3 gc = mix(c, vec3(1.0) - c * 0.5, step(0.75, hash(vec2(sign_seed, 1.0))));
	float flick = 1.0;
	float fr = hash(vec2(sign_seed, 9.0));
	if (fr > 0.8) {
		flick = step(0.08, fract(TIME * (0.3 + fr) + fr * 13.0));
	}
	col += mix(c * brightness * flick, vec3(0.9) - col, day) * border;
	col = mix(col + gc * glyph * brightness * 0.8 * flick, mix(col, vec3(0.95), glyph), day);
	ALBEDO = col;
}
