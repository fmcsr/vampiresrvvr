shader_type spatial;

// Desert ground: dusky sand with broad dunes and wind ripples. Inside the walls the surface stays
// flat (effects are drawn just above y = 0); outside them the sand piles up against the walls and
// rolls away in real dunes that fade into the night. Also used by the low sand drifts around props.

#include "res://shaders/desert_sand.gdshaderinc"

// Outer face of the arena walls (m from the center).
uniform float wall_line = 61.5;
// Sand piled against the outside of the walls, and the dunes beyond it (m).
uniform float drift_height = 1.8;
uniform float dune_height = 3.5;
// How dark the sand gets far outside the walls.
uniform float outside_darkening = 0.6;

varying vec3 world_position;

float outside_height(vec2 xz) {
	float outside = max(abs(xz.x), abs(xz.y)) - wall_line;
	if (outside <= -1.0) {
		return 0.0;
	}
	float drift = smoothstep(-1.0, 5.0, outside) * drift_height * (0.6 + 0.8 * sand_noise(xz * 0.07));
	float dunes = smoothstep(3.0, 26.0, outside) * dune_height * sand_fbm(xz * 0.022 + vec2(3.0, 8.0));
	return drift + dunes;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = outside_height(world_position.xz);
	if (height > 0.0) {
		float step_size = 0.75;
		float height_x = outside_height(world_position.xz + vec2(step_size, 0.0));
		float height_z = outside_height(world_position.xz + vec2(0.0, step_size));
		NORMAL = normalize(vec3(height - height_x, step_size, height - height_z));
		VERTEX.y += height;
		world_position.y += height;
	}
}

void fragment() {
	vec2 xz = world_position.xz;
	vec4 layout = sand_layout(xz);
	vec3 ripples = sand_ripples(xz, sand_ripple_fade(xz));
	vec3 albedo = sand_albedo(xz, layout, ripples.x);
	float outside = max(abs(xz.x), abs(xz.y)) - wall_line;
	albedo *= 1.0 - outside_darkening * smoothstep(0.0, 28.0, outside);
	// Bend the surface normal (flat ground, dune slope or drift mound) by the sand's own slopes.
	vec3 surface = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 sand = sand_normal(xz, ripples);
	vec3 normal = normalize(surface + vec3(sand.x, 0.0, sand.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
}
