shader_type spatial;
// Procedural facade for one box-shaped building tier. The mesh is a unit box
// scaled by the tier size (an unscaled box mesh also works), so every facade
// is laid out in metres: shop band on the ground floor, a window grid with
// frames, sills and floor slabs, corner pilasters, a parapet band, grime and
// rooftop gravel. Damage adds soot and blacks out windows.
// style: 0 office grid, 1 classic punched windows, 2 glass curtain wall, 3 art-deco piers.
// MultiMesh skylines set use_custom: COLOR tints the wall and INSTANCE_CUSTOM.x is a seed.

uniform vec4 wall_color : source_color = vec4(0.32, 0.34, 0.38, 1.0);
uniform vec4 trim_color : source_color = vec4(0.2, 0.21, 0.24, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform vec4 glass_color : source_color = vec4(0.05, 0.075, 0.11, 1.0);
uniform vec4 roof_color : source_color = vec4(0.28, 0.28, 0.3, 1.0);
uniform vec2 cell = vec2(1.0, 1.0);
uniform float lit_ratio = 0.35;
uniform float seed = 0.0;
uniform float damage = 0.0;
uniform float emission_strength = 2.5;
uniform float shop_emission = 1.0;
uniform int style = 0;
uniform float snow = 0.0;
uniform float ground_floor = 1.5;
uniform float sink = 0.0;
uniform bool use_custom = false;
uniform bool shop_band = true;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 hs;
varying float base_off;
varying vec3 tint;
varying float iseed;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + iseed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float box2(vec2 f, vec4 r) {
	return step(r.x, f.x) * step(f.x, r.z) * step(r.y, f.y) * step(f.y, r.w);
}

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lpos = VERTEX * sc;
	lnrm = NORMAL;
	// Half size: a unit box scaled by the tier size gives the size directly.
	hs = 0.5 * sc;
	if (sc.x < 1.01 && sc.y < 1.01 && sc.z < 1.01) {
		hs = vec3(4.0, 8.0, 4.0);
	}
	base_off = MODEL_MATRIX[3].y - sink;
	tint = vec3(1.0);
	iseed = seed;
	if (use_custom) {
		tint = COLOR.rgb;
		iseed = seed + INSTANCE_CUSTOM.x * 17.0;
	}
}

void fragment() {
	vec3 n = abs(lnrm);
	float yabs = lpos.y + base_off;
	vec3 wallc = wall_color.rgb * tint;
	vec3 trimc = trim_color.rgb * tint;
	float soot = damage * smoothstep(0.2, 1.0, vnoise(lpos.xy * 0.35 + lpos.z * 0.2 + 3.1));
	vec3 col;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	float ao = 1.0;

	if (n.y > 0.5) {
		// Roof: gravel with a raised light parapet ring and tar seams.
		vec2 r = lpos.xz;
		float edge = min(hs.x - abs(r.x), hs.z - abs(r.y));
		float grav = vnoise(r * 6.0) * 0.5 + vnoise(r * 1.3) * 0.5;
		col = roof_color.rgb * (0.75 + grav * 0.35);
		float seam = step(0.96, fract(r.x * 0.5)) + step(0.96, fract(r.y * 0.5));
		col *= 1.0 - clamp(seam, 0.0, 1.0) * 0.25;
		col = mix(col, trimc * 1.25, step(edge, 0.22));
		ao = mix(0.7, 1.0, smoothstep(0.22, 0.9, edge));
		if (lnrm.y < 0.0) {
			col = trimc * 0.5;
		}
		col = mix(col, vec3(0.92, 0.94, 0.98), snow * smoothstep(0.3, 0.6, grav + 0.25));
		rough = 0.95;
	} else {
		bool side = n.x > 0.5;
		float u = side ? lpos.z : lpos.x;
		float half_w = side ? hs.z : hs.x;
		float top = base_off + hs.y;
		float tier_base = base_off - hs.y;
		float face_seed = side ? 37.0 : 0.0;

		// Fit a whole number of window columns between the corner pilasters.
		float margin = style == 2 ? 0.12 : 0.32;
		float avail = max(2.0 * half_w - 2.0 * margin, 0.5);
		float ncols = max(1.0, floor(avail / cell.x + 0.3));
		float cw = avail / ncols;
		float uu = (u + half_w - margin) / cw;
		float colid = floor(uu);
		float fx = fract(uu);
		bool in_cols = uu >= 0.0 && uu < ncols;

		float gf = (shop_band && tier_base < 0.5) ? ground_floor : max(tier_base, 0.0);
		float yy = yabs - gf;
		float rowid = floor(yy / cell.y);
		float fy = fract(yy / cell.y);
		float parapet = top - (style == 2 ? 0.25 : 0.5);
		bool in_rows = yy > 0.0 && yabs < parapet;

		// Grime: vertical rain streaks and dirt near the street.
		float streak = vnoise(vec2(u * 2.3, yabs * 0.08 + face_seed));
		float grime = streak * 0.22 + (1.0 - smoothstep(0.0, 3.0, yabs)) * 0.15;
		vec3 wall = wallc * (1.0 - grime);
		// Fine masonry / panel texture.
		wall *= 0.94 + vnoise(vec2(u, yabs) * 9.0) * 0.08;

		// Corner pilasters.
		float pil = step(half_w - margin, abs(u));
		wall = mix(wall, mix(wallc, trimc, 0.45) * (1.0 - grime * 0.5), pil);

		col = wall;
		float win = 0.0;
		float frame = 0.0;
		float lit = 0.0;
		float glassv = 0.0;

		if (in_cols && in_rows) {
			vec4 wr;
			if (style == 0) {
				wr = vec4(0.05, 0.3, 0.95, 0.94);
			} else if (style == 1) {
				wr = vec4(0.25, 0.2, 0.75, 0.8);
			} else if (style == 2) {
				wr = vec4(0.02, 0.07, 0.98, 0.97);
			} else {
				wr = vec4(0.2, 0.14, 0.8, 0.88);
			}
			win = box2(vec2(fx, fy), wr);
			vec4 inner = wr + vec4(0.035, 0.045, -0.035, -0.04) * (style == 2 ? 0.5 : 1.0);
			float glass = box2(vec2(fx, fy), inner);
			frame = win - glass;
			// Mullion splitting the pane.
			float mull = (style == 1) ? max(step(abs(fx - 0.5), 0.012), step(abs(fy - 0.62), 0.012)) : step(abs(fract(fx * 2.0) - 0.5), 0.01) * float(style != 2);
			glass *= 1.0 - mull;
			frame = max(frame, mull * win);
			glassv = glass;

			vec2 id = vec2(colid + face_seed, rowid);
			float r = hash(id);
			lit = step(1.0 - lit_ratio, r) * step(damage * 1.3, hash(id + 7.3));
			// Lit rooms vary in warmth and brightness; some have blinds half down.
			float warm = hash(id + 2.7);
			float blind = step(0.7, hash(id + 5.1)) * step(fy, mix(wr.y, wr.w, 0.45));
			vec3 alt = warm > 0.5 ? vec3(1.0, 0.86, 0.62) : vec3(0.78, 0.88, 1.0);
			vec3 lc = mix(lit_color.rgb, alt, step(0.45, hash(id + 6.1)) * 0.75) * (0.55 + 0.55 * hash(id + 9.9));
			// Fake interior depth: darker toward the window head.
			float depth = smoothstep(wr.w, wr.y, fy);
			vec3 gl = glass_color.rgb * (0.7 + 0.6 * hash(id + 3.3)) * (0.75 + 0.35 * depth);
			// Sky reflection gradient over the facade.
			gl += vec3(0.05, 0.07, 0.1) * (fy - 0.3) * (style == 2 ? 2.0 : 1.0);
			vec3 g = mix(gl, lc * 0.5, lit);
			vec3 framec = style == 1 ? mix(vec3(0.8, 0.78, 0.74), trimc, 0.5) : trimc * 0.7;
			col = mix(col, framec, frame);
			col = mix(col, g, glass);
			emit = lc * lit * glass * (1.0 - blind * 0.7) * emission_strength;
			ao = mix(ao, 0.6 + 0.4 * depth, glass);

			// Classic: sill under the window and lintel above.
			if (style == 1) {
				float sill = box2(vec2(fx, fy), vec4(0.2, 0.13, 0.8, 0.2));
				float lintel = box2(vec2(fx, fy), vec4(0.22, 0.8, 0.78, 0.86));
				col = mix(col, mix(trimc, vec3(0.9), 0.35) + snow * 0.4 * sill, max(sill, lintel));
				ao *= 1.0 - 0.3 * box2(vec2(fx, fy), vec4(0.2, 0.08, 0.8, 0.13));
			}
			// Office: spandrel panel and slab line.
			if (style == 0) {
				col = mix(col, trimc * 0.85, step(fy, 0.04));
			}
			// Deco: lighter vertical piers between window columns.
			if (style == 3) {
				float pier = 1.0 - step(0.12, fx) * step(fx, 0.88);
				col = mix(col, mix(wallc, vec3(0.9, 0.86, 0.78), 0.3), pier * (1.0 - win));
			}
		}

		// Ground-floor shops: big lit windows under a coloured sign band.
		if (shop_band && tier_base < 0.5 && yabs < gf) {
			float sc = max(1.0, floor(2.0 * half_w / 2.6));
			float sw = 2.0 * half_w / sc;
			float su = (u + half_w) / sw;
			float sid = floor(su) + face_seed;
			float sf = fract(su);
			float sh = hash(vec2(sid, 91.0));
			vec3 signc = 0.5 + 0.5 * cos(6.2831 * (sh + vec3(0.0, 0.33, 0.67)));
			float signb = box2(vec2(sf, yabs), vec4(0.04, gf - 0.42, 0.96, gf - 0.1));
			float shopw = box2(vec2(sf, yabs), vec4(0.1, 0.05, 0.9, gf - 0.55));
			float door = box2(vec2(sf, yabs), vec4(0.42, 0.0, 0.58, gf - 0.55));
			vec3 shopc = mix(vec3(1.0, 0.8, 0.55), signc, 0.25);
			float shop_lit = step(damage * 1.2, sh) * (0.5 + 0.5 * hash(vec2(sid, 4.0)));
			col = mix(trimc * 0.6, col, 0.0);
			col = mix(col, signc * 0.6, signb);
			col = mix(col, mix(glass_color.rgb, shopc * 0.6, shop_lit * 0.8), max(shopw, door));
			emit += signc * signb * shop_emission * 0.8 * step(0.3, sh);
			emit += shopc * shopw * shop_lit * shop_emission * 0.6;
			glassv = max(glassv, shopw);
			// Awning shadow strip.
			ao *= 1.0 - 0.35 * box2(vec2(sf, yabs), vec4(0.0, gf - 0.6, 1.0, gf - 0.42));
		}

		// Parapet / cornice band and floor slab ledges.
		float cornice = step(parapet, yabs);
		col = mix(col, trimc * (1.0 + step(top - 0.12, yabs) * 0.4), cornice);
		float slab = (shop_band && tier_base < 0.5) ? step(abs(yabs - gf), 0.06) : 0.0;
		col = mix(col, trimc, slab);
		// Snow caught on ledges.
		col = mix(col, vec3(0.9, 0.92, 0.96), snow * (step(top - 0.08, yabs) + slab) * 0.8);
		// Contact darkening at the tier base.
		ao *= mix(0.65, 1.0, smoothstep(0.0, 1.2, yabs - max(tier_base, 0.0)));

		rough = mix(0.88, 0.08, glassv * (1.0 - lit));
		metal = glassv * (1.0 - lit) * (style == 2 ? 0.8 : 0.55);
	}

	col *= 1.0 - soot * 0.8;
	emit *= 1.0 - soot;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	EMISSION = emit;
}
