shader_type particles;
render_mode disable_force, disable_velocity;

#include "wind_field.gdshaderinc"

uniform vec3 emission_extents = vec3(18.0, 2.5, 18.0);
uniform float travel_speed : hint_range(0.0, 20.0) = 5.0;
uniform float velocity_response : hint_range(0.1, 10.0) = 1.8;
uniform float wandering : hint_range(0.0, 2.0) = 0.35;
uniform float calm_visibility : hint_range(0.0, 1.0) = 0.25;

void start() {
	float seed = wind_hash(float(NUMBER) + float(RANDOM_SEED % uint(65536)));
	vec3 spawn = vec3(
		wind_hash(seed * 137.1), wind_hash(seed * 269.5), wind_hash(seed * 419.2)
	) * 2.0 - 1.0;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3] = EMISSION_TRANSFORM * vec4(spawn * emission_extents, 1.0);
	CUSTOM = vec4(seed, 0.0, 0.0, mix(0.72, 1.0, wind_hash(seed * 73.9)));
	vec2 dir = wind_dir_2d();
	TRANSFORM[3].xyz -= vec3(dir.x, 0.0, dir.y) * travel_speed * LIFETIME
		* wind_strength * (1.0 + wind_gust_strength * 0.5) * 0.6;
	VELOCITY = vec3(dir.x, 0.0, dir.y) * travel_speed * wind_strength * 2.0;
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
	CUSTOM.y += DELTA / max(LIFETIME * CUSTOM.w, 0.001);
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}
	float gust;
	vec3 flow = wind_sample(TRANSFORM[3].xyz, CUSTOM.x, gust);
	vec2 dir = wind_dir_2d();
	vec3 sideways = vec3(-dir.y, 0.0, dir.x);
	float phase = CUSTOM.x * TAU;
	float drift = sin(TIME * wind_speed * 0.85 + phase)
		+ 0.3 * sin(TIME * wind_speed * 1.37 + phase * 2.3);
	flow += sideways * drift * wandering;
	flow.y += sin(TIME * wind_speed * 0.67 + phase * 1.7) * wandering * 0.22;
	float speed_variation = mix(0.8, 1.2, wind_hash(CUSTOM.x * 57.3));
	vec3 target_velocity = flow * travel_speed * speed_variation * wind_strength * 2.0;
	VELOCITY = mix(VELOCITY, target_velocity, 1.0 - exp(-velocity_response * DELTA));
	TRANSFORM[3].xyz += VELOCITY * DELTA;

	vec3 forward = length(VELOCITY) > 0.0001 ? normalize(VELOCITY) : vec3(dir.x, 0.0, dir.y);
	vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
	TRANSFORM[0].xyz = right;
	TRANSFORM[1].xyz = forward;
	TRANSFORM[2].xyz = normalize(cross(right, forward));
	CUSTOM.z = gust;
	float life_fade = smoothstep(0.0, 0.14, CUSTOM.y) * (1.0 - smoothstep(0.65, 1.0, CUSTOM.y));
	float gust_visibility = smoothstep(CUSTOM.x * 0.65, CUSTOM.x * 0.65 + 0.35, gust);
	COLOR.a = life_fade * mix(calm_visibility, 1.0, gust_visibility)
		* smoothstep(0.0, 0.08, wind_strength);
}
