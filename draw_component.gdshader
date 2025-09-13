shader_type canvas_item;
//render_mode unshaded; // optional

// Fog density
uniform float density: hint_range(0.0, 1.0) = 0.2;

// Fog speed
uniform vec2 speed = vec2(0.2, 0.1);

// Noise scale
uniform float noise_scale: hint_range(0.1, 10.0) = 8.547;

// Multiple layers for more natural fog
uniform int octaves: hint_range(1, 4) = 4;
uniform float octave_scale: hint_range(0.1, 1.0) = 0.318;
uniform float frequency_multiplier: hint_range(1.0, 4.0) = 3.0;

// Control for fog coverage area
uniform float fog_threshold: hint_range(0.0, 1.0) = 0.75;
uniform float fog_softness: hint_range(0.01, 0.5) = 0.5;

// Control for discrete cloud regions
uniform float cloud_scale: hint_range(0.1, 5.0) = 1.0;
uniform float cloud_threshold: hint_range(0.0, 1.0) = 0.6;

// Color controls
uniform vec4 fog_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float color_variation: hint_range(0.0, 1.0) = 0.2;
uniform vec4 variation_color: source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float edge_darkening: hint_range(0.0, 1.0) = 0.3;

// Procedural noise function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise_procedural(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float get_procedural_noise(vec2 uv) {
	float result = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;

	for (int i = 0; i < octaves; i++) {
		result += noise_procedural(uv * frequency * noise_scale) * amplitude;
		frequency *= frequency_multiplier;
		amplitude *= octave_scale;
	}

	return result;
}

void fragment() {
	// Make the fog slowly move
	vec2 uv = UV + speed * TIME;

	// Generate large-scale noise for cloud regions
	float cloud_mask = noise_procedural(uv * cloud_scale);
	cloud_mask = smoothstep(cloud_threshold, cloud_threshold + 0.2, cloud_mask);

	// Generate detailed procedural noise for fog texture
	float noise = get_procedural_noise(uv);

	// Normalize and apply contrast
	noise = clamp(noise, 0.0, 1.0);

	// Convert to fog alpha with controllable threshold and softness
	float fog = smoothstep(fog_threshold, fog_threshold + fog_softness, noise);

	// Multiply fog by cloud mask to create discrete regions
	fog *= cloud_mask;

	// Create color variation based on noise
	float color_noise = noise_procedural(uv * noise_scale * 0.5);
	vec4 final_fog_color = mix(fog_color, variation_color, color_noise * color_variation);

	// Add edge darkening for more realistic clouds
	float edge_factor = smoothstep(0.0, 0.3, fog) * smoothstep(1.0, 0.7, fog);
	final_fog_color.rgb = mix(final_fog_color.rgb * (1.0 - edge_darkening), final_fog_color.rgb, edge_factor);

	// Set the color and alpha for the fog overlay
	COLOR = final_fog_color;
	COLOR.a *= fog * density;
}