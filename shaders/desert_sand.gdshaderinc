// Desert sand shared by the ground and by everything that sits in it (floor tiles, dusty stone),
// so sand drifting over a prop has exactly the color and ripples of the ground around it.
// The layout mask is painted by scripts/world/arena.gd: R = stone floor exposure (1 = swept clear),
// G = darker hollow around a prop, B = damp ground under grass.

uniform vec3 sand_light : source_color = vec3(0.56, 0.45, 0.33);
uniform vec3 sand_dark : source_color = vec3(0.46, 0.36, 0.26);
// Wind ripples: distance between crests (m) and their steepest slope.
uniform float ripple_wavelength = 0.75;
uniform float ripple_strength = 0.1;
// Height (m) of the broad, low dunes; they only shade the sand, the playable ground stays flat.
uniform float dune_strength = 2.0;
uniform sampler2D layout_mask : hint_default_black, filter_linear, repeat_disable;
// World rectangle covered by the layout mask: x, z of the corner, then width and depth.
uniform vec4 mask_rect = vec4(-64.0, -64.0, 128.0, 128.0);

float sand_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise in 0..1.
float sand_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(sand_hash(i), sand_hash(i + vec2(1.0, 0.0)), u.x),
			mix(sand_hash(i + vec2(0.0, 1.0)), sand_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Value noise with its derivatives: (value, d/dx, d/dy).
vec3 sand_noised(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = sand_hash(i);
	float b = sand_hash(i + vec2(1.0, 0.0));
	float c = sand_hash(i + vec2(0.0, 1.0));
	float d = sand_hash(i + vec2(1.0, 1.0));
	float k4 = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k4 * u.x * u.y,
			du * vec2(b - a + k4 * u.y, c - a + k4 * u.x));
}

// Three octaves, about 0..0.88.
float sand_fbm(vec2 p) {
	float sum = 0.5 * sand_noise(p);
	sum += 0.25 * sand_noise(p * 2.07 + vec2(17.3, 9.1));
	sum += 0.125 * sand_noise(p * 4.13 + vec2(-5.7, 31.4));
	return sum;
}

vec4 sand_layout(vec2 xz) {
	return texture(layout_mask, (xz - mask_rect.xy) / mask_rect.zw);
}

// Ripple height (-1..1, already scaled by fade) and its slope (d/dx, d/dz) at xz.
// fade goes to 0 where the ripples would be finer than a few pixels.
vec3 sand_ripples(vec2 xz, float fade) {
	vec2 warp = vec2(sand_noise(xz * 0.13), sand_noise(xz * 0.13 + vec2(43.0, 17.0)));
	vec2 direction = normalize(vec2(0.35, 1.0));
	float frequency = 6.2832 / ripple_wavelength;
	float phase = dot(xz, direction) * frequency + (warp.x * 2.0 + warp.y) * 5.0;
	// Gentle windward side, steeper lee side.
	float height = sin(phase) + 0.22 * sin(2.0 * phase);
	float slope = cos(phase) + 0.44 * cos(2.0 * phase);
	// Patches of strong and faint ripples.
	float amount = fade * smoothstep(0.35, 0.8, sand_noise(xz * 0.045 + vec2(7.0, 3.0)));
	return vec3(height * amount, direction * slope * amount * ripple_strength);
}

float sand_ripple_fade(vec2 xz) {
	float frequency = 6.2832 / ripple_wavelength;
	float change = length(fwidth(xz)) * frequency;
	return 1.0 - smoothstep(0.6, 1.6, change);
}

vec3 sand_albedo(vec2 xz, vec4 layout, float ripple_height) {
	float tone = sand_fbm(xz * 0.03);
	float grain = sand_noise(xz * 2.7);
	vec3 color = mix(sand_dark, sand_light, smoothstep(0.15, 0.8, tone));
	color *= 0.94 + 0.1 * grain + 0.05 * ripple_height;
	// Damp, darker ground under the grass.
	color = mix(color, color * vec3(0.72, 0.76, 0.6), layout.b);
	// Swept hollows around props.
	color *= 1.0 - 0.45 * layout.g;
	return color;
}

// World-space normal of the sand surface: broad dunes plus the ripples' slope.
vec3 sand_normal(vec2 xz, vec3 ripples) {
	vec3 dune = sand_noised(xz * 0.045 + vec2(11.0, 5.0));
	vec2 slope = dune.yz * 0.045 * dune_strength + ripples.yz;
	return normalize(vec3(-slope.x, 1.0, -slope.y));
}
