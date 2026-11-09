shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

// Dry desert grass tufts (procedural blades built by scripts/world/arena.gd) swaying in the wind.
// UV.y runs from the root (0) to the tip (1); multimesh custom data x moves the tuft's color from
// dry straw to dusty green. Lit as if facing up so the tufts shade like the ground they grow in.

uniform vec3 root_color : source_color = vec3(0.27, 0.22, 0.13);
uniform vec3 straw_color : source_color = vec3(0.64, 0.55, 0.3);
uniform vec3 green_color : source_color = vec3(0.45, 0.48, 0.22);
// Sideways bend of a blade tip (m) and wind speed.
uniform float sway = 0.12;
uniform float wind_speed = 1.4;

varying float blade_height;
varying flat float hue;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = TIME * wind_speed + origin.x * 0.21 + origin.z * 0.13;
	float gust = sin(phase) * 0.7 + sin(phase * 2.7 + 1.3) * 0.3;
	VERTEX.xz += vec2(1.0, 0.45) * gust * sway * UV.y * UV.y;
	blade_height = UV.y;
	hue = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 tip = mix(straw_color, green_color, hue);
	ALBEDO = mix(root_color, tip, smoothstep(0.0, 0.85, blade_height));
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
