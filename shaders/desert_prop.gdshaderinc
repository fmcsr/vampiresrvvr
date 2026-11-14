// KayKit props in the desert: the pack's gradient atlas, warmed and desaturated, its teal plants
// turned into dry moss, sand dust at the foot and on upward faces. Floor tiles (drift_cover = 1) also
// get drifted sand where the layout mask says the floor is buried, using the ground's own sand.
// Shared by desert_prop.gdshader and desert_prop_broken.gdshader (BROKEN defined).

#include "res://shaders/desert_sand.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap;
// Multiplies the atlas color (linear), after desaturating it.
uniform vec3 tint = vec3(1.0);
uniform float saturation = 0.8;
uniform float brightness = 1.0;
// Each instance is a little lighter or darker than the next, by up to this much.
uniform float shade_variation = 0.12;
// Broad weathering stains across the world (floor tiles), so a large floor isn't one flat color.
uniform float stain = 0.0;
uniform vec3 moss_color : source_color = vec3(0.45, 0.42, 0.22);
// Sand dust at the foot of the prop (amount, height in m) and on its upward faces.
uniform float ground_dust = 0.6;
uniform float dust_height = 0.7;
uniform float top_dust = 0.3;
// 1 for floor tiles: sand drifts over them where the layout mask's exposure is low.
uniform float drift_cover = 0.0;
// Emission strength for the atlas' flame colors (torches, lanterns, candles).
uniform float glow = 0.0;
uniform float roughness = 0.85;

varying vec3 world_position;
varying vec3 world_normal;
varying flat float shade;
#ifdef BROKEN
varying vec3 local_position;
varying flat vec4 break_shape;
#endif

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	shade = sand_hash(floor(MODEL_MATRIX[3].xz * 4.0) + vec2(0.5, 3.5));
#ifdef BROKEN
	local_position = VERTEX;
	break_shape = INSTANCE_CUSTOM;
#endif
}

void fragment() {
#ifdef BROKEN
	// Multimesh custom data: x = break height (model space), y = jag size, z = seed,
	// w = 1 for a solid piece (stone top) or 0 for a hollow one (barrel).
	float angle = atan(local_position.z, local_position.x);
	float jag = (sand_noise(vec2(angle * 1.9 + break_shape.z * 17.0, break_shape.z * 5.0)) - 0.5) * 2.0 * break_shape.y;
	if (local_position.y > break_shape.x + jag + local_position.x * 0.12) {
		discard;
	}
#endif
	vec3 base = texture(atlas, UV).rgb;
	vec3 albedo = base;
	float teal = smoothstep(0.12, 0.3, albedo.g - albedo.r) * smoothstep(-0.12, 0.0, albedo.g - albedo.b);
	albedo = mix(albedo, moss_color * (0.55 + albedo.g * 0.7), teal);
	float luminance = dot(albedo, vec3(0.3, 0.59, 0.11));
	albedo = mix(vec3(luminance), albedo, saturation) * tint * brightness;
	albedo *= 1.0 + (shade - 0.5) * 2.0 * shade_variation;
	albedo *= 1.0 + (sand_fbm(world_position.xz * 0.12 + vec2(3.1, 7.7)) - 0.45) * stain;

	vec4 layout = sand_layout(world_position.xz);
	vec3 sand = sand_albedo(world_position.xz, layout, 0.0);
	float grain = sand_noise(world_position.xz * 3.1 + vec2(world_position.y * 2.3));
	float dust = ground_dust * (1.0 - smoothstep(0.0, dust_height, world_position.y - 0.25 * grain));
	dust += top_dust * smoothstep(0.6, 0.92, world_normal.y) * (0.35 + 0.65 * grain);
	float cover = 0.0;
	if (drift_cover > 0.0) {
		// Where the drift wave rises above the floor's exposure the tile is fully buried, so it
		// matches the open sand next to it; just short of that the stone is dusty.
		float drift = sand_fbm(world_position.xz * 0.42) * 1.2 - layout.r;
		cover = drift_cover * smoothstep(-0.04, 0.04, drift);
		dust = max(dust, drift_cover * 0.45 * smoothstep(-0.3, 0.0, drift));
		vec3 ripples = sand_ripples(world_position.xz, sand_ripple_fade(world_position.xz));
		vec3 sand_up = normalize((VIEW_MATRIX * vec4(sand_normal(world_position.xz, ripples), 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, sand_up, cover));
		sand = sand_albedo(world_position.xz, layout, ripples.x);
	}
	float sandy = clamp(max(dust, cover), 0.0, 1.0);
	albedo = mix(albedo, sand, sandy);
	// Contact darkening in the hollows around props, only near the ground (the sand has its own).
	albedo *= 1.0 - 0.45 * layout.g * (1.0 - smoothstep(0.0, 0.5, world_position.y)) * (1.0 - sandy);
#ifdef BROKEN
	if (!FRONT_FACING) {
		// Seen through the break: a rough stone top for solid pieces, a dark inside for hollow ones.
		if (break_shape.w > 0.5) {
			albedo *= 0.8;
			NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		} else {
			albedo *= 0.3;
		}
	}
#endif
	ALBEDO = albedo;
	// Sand on the prop shines exactly like the ground (sand.gdshader).
	ROUGHNESS = mix(roughness, 0.94, sandy);
	SPECULAR = mix(0.3, 0.2, sandy);
	float flame = smoothstep(0.8, 0.95, base.r) * smoothstep(0.45, 0.6, base.g) * (1.0 - smoothstep(0.45, 0.6, base.b));
	EMISSION = base * flame * glow;
}
