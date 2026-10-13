shader_type spatial;
// Kaiju hide: object-space triplanar detail with two layers of relief
// (large raised tubercles and fine scales), a dark cavity tint between
// them, a mottled two-tone colour with darker back and paler underside,
// optional ribbed bands (belly plates), rim light and a translucent
// backlight for a fleshy, sculpted look. flash_color is driven by
// KaijuModel.flash().

uniform vec4 albedo : source_color = vec4(0.2, 0.33, 0.3, 1.0);
uniform vec4 albedo_dark : source_color = vec4(0.1, 0.16, 0.15, 1.0);
uniform vec4 cavity_color : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform vec4 backlight_color : source_color = vec4(0.35, 0.08, 0.05, 1.0);
uniform float roughness = 0.6;
uniform sampler2D scale_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D scale_mask : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D bump_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float scale_size = 1.6;
uniform float bump_size = 0.45;
uniform float scale_strength = 1.0;
uniform float bump_strength = 1.0;
uniform float cavity = 0.6;
uniform float ribs = 0.0;
uniform float rim = 0.5;
uniform vec3 flash_color = vec3(0.0);

varying vec3 opos;
varying vec3 onrm;

vec3 tri_n(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

float tri_f(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).r * w.x + texture(tex, p.xz).r * w.y + texture(tex, p.xy).r * w.z;
}

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(onrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 n1 = tri_n(scale_normal, opos * scale_size, w) * 2.0 - 1.0;
	vec3 n2 = tri_n(bump_normal, opos * bump_size, w) * 2.0 - 1.0;
	vec3 nm = normalize(vec3(n1.xy * scale_strength + n2.xy * bump_strength, 1.0));
	float edge = tri_f(scale_mask, opos * scale_size, w);
	float mot = tri_f(mottle, opos * 0.3, w);

	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float up = wn.y * 0.5 + 0.5;
	vec3 col = mix(albedo.rgb, albedo_dark.rgb, smoothstep(0.3, 0.8, mot) * 0.6);
	// Countershading: darker back, paler underside.
	col *= mix(1.12, 0.78, up);
	// Cavity tint in the gaps between scales.
	float cav = smoothstep(0.45, 0.85, edge) * cavity * scale_strength;
	col = mix(col, cavity_color.rgb, cav);
	// Belly plate bands.
	float band_ao = 1.0;
	if (ribs > 0.0) {
		float band = abs(fract(opos.y * ribs) - 0.5) * 2.0;
		band_ao = mix(0.55, 1.0, smoothstep(0.0, 0.3, band));
		col *= band_ao;
	}
	ALBEDO = col;
	NORMAL_MAP = nm * 0.5 + 0.5;
	ROUGHNESS = clamp(roughness + cav * 0.3, 0.0, 1.0);
	SPECULAR = 0.5;
	RIM = rim;
	RIM_TINT = 0.4;
	BACKLIGHT = backlight_color.rgb;
	AO = (1.0 - cav * 0.6) * band_ao;
	AO_LIGHT_AFFECT = 0.25;
	EMISSION = flash_color;
}
