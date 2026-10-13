shader_type spatial;
// Kaiju spikes, plates, claws and horns: a base-to-tip colour gradient
// (UV.y = 0 at the tip) with an emissive tip that brightens with rage.

uniform vec4 base_color : source_color = vec4(0.15, 0.2, 0.2, 1.0);
uniform vec4 tip_color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float glow_energy = 0.3;
uniform float roughness = 0.35;
uniform float gloss_ridges = 1.0;
uniform vec3 flash_color = vec3(0.0);

void fragment() {
	float t = clamp(1.0 - UV.y, 0.0, 1.0);
	float g = smoothstep(0.15, 0.95, t);
	// Fine growth ridges along the length.
	float ridge = 0.9 + 0.1 * sin(UV.y * 60.0) * gloss_ridges;
	ALBEDO = mix(base_color.rgb, tip_color.rgb, g) * ridge;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
	RIM = 0.4;
	RIM_TINT = 0.6;
	EMISSION = glow_color.rgb * glow_energy * (0.15 + 0.85 * t * t) + flash_color;
}
