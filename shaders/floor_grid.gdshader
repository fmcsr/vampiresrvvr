shader_type spatial;

// Graybox floor: stone tiles with slight color variation and thin grout lines.
// Exists to give a sense of motion on the flat floor; to be replaced with real art.

uniform vec3 base_color : source_color = vec3(0.13, 0.12, 0.14);
uniform vec3 line_color : source_color = vec3(0.05, 0.045, 0.055);
uniform float cell_size = 2.0;
uniform float tile_variation = 0.35;

varying vec3 world_position;

float tile_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_position.xz / cell_size;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = 1.0 - clamp(min(grid.x, grid.y) - 0.5, 0.0, 1.0);
	vec3 tile = base_color * (1.0 - tile_variation * 0.5 + tile_variation * tile_hash(floor(coord)));
	ALBEDO = mix(tile, line_color, line);
	ROUGHNESS = 0.92;
}
