shader_type sky;
// Static procedural sky: gradient, sun disk and halo, a layer of fbm clouds
// lit by the sun, stars at night and a city glow along the horizon.
// No TIME, so the radiance map is only rendered once.

uniform vec3 top_color : source_color = vec3(0.3, 0.45, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.8, 0.8);
uniform vec3 ground_color : source_color = vec3(0.3, 0.3, 0.3);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.5, 0.52, 0.58);
uniform vec3 city_glow : source_color = vec3(0.0);
uniform float cover = 0.45;
uniform float cloud_density = 1.0;
uniform float stars = 0.0;
uniform float sun_size = 0.03;
uniform float sun_strength = 1.0;
uniform float curve = 0.25;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), curve));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	// City light pollution at the horizon.
	col += city_glow * exp(-abs(h) * 9.0);

	vec3 sun_dir = LIGHT0_DIRECTION;
	float sd = max(dot(d, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	if (LIGHT0_ENABLED) {
		col += sun_col * pow(sd, 8.0) * 0.25 * sun_strength;
		col += sun_col * pow(sd, 64.0) * 0.5 * sun_strength;
	}

	if (h > 0.0) {
		// Stars.
		if (stars > 0.0) {
			vec2 sp = d.xz / (h + 0.3) * 160.0;
			float s = hash(floor(sp));
			vec2 f = fract(sp) - 0.5;
			float star = step(0.985, s) * smoothstep(0.25, 0.0, length(f)) * (0.5 + hash(floor(sp) + 3.0));
			col += vec3(star) * stars * smoothstep(0.02, 0.3, h);
		}
		// Clouds on a plane overhead.
		vec2 uv = d.xz / (h + 0.12) * 0.9;
		float n = fbm(uv * 1.3 + vec2(3.0, 1.0));
		float m = smoothstep(1.0 - cover - 0.05, 1.0 - cover + 0.35, n) * cloud_density;
		float n2 = fbm(uv * 1.3 + vec2(3.0, 1.0) + sun_dir.xz * 0.12);
		float lightness = clamp(0.5 + (n - n2) * 4.0, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_color, lightness);
		if (LIGHT0_ENABLED) {
			cc += sun_col * pow(sd, 6.0) * 0.35 * (1.0 - m * 0.5);
		}
		cc += city_glow * 0.6 * (1.0 - lightness);
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, cc, m * fade);
		// Sun disk (behind clouds).
		if (LIGHT0_ENABLED) {
			float disk = smoothstep(cos(sun_size), cos(sun_size * 0.8), sd);
			col += sun_col * disk * 6.0 * (1.0 - m) * sun_strength;
		}
	}
	COLOR = col;
}
