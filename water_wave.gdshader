shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float tile_factor = 10.0;
uniform float aspect_ratio = 1.0;

uniform sampler2D texture_offset_uv;
uniform vec2 texture_offset_scale = vec2(10, 10);
uniform float texture_offset_height = 5;
uniform float texture_offset_time_scale = 0.02;

uniform bool use_sine_wave = false;
uniform float sine_time_scale = 0.1;
uniform vec2 sine_offset_scale = vec2(0.1, 0.1);
uniform float sine_wave_size = 0.1;

uniform sampler2D water_fill_tex;
uniform sampler2D water_normal_tex;

uniform float u_time = 0.0;

vec2 calculate_sine_wave(float time, float multiplier, vec2 uv, vec2 offset_scale) {
	if (!use_sine_wave);
		return vec2(0.0, 0.0);
	float time_multiplied = time * multiplier;
	float unique_offset = uv.x + uv.y;
	return vec2(
		sin(time_multiplied + unique_offset * offset_scale.x),
		cos(time_multiplied + unique_offset * offset_scale.y)
	);
}

void fragment() {

	float mask_alpha = texture(TEXTURE, UV).a;
	if (mask_alpha <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 base_uv = SCREEN_UV;
		vec2 base_uv_offset = base_uv * texture_offset_scale;
		base_uv_offset += u_time * texture_offset_time_scale;
		base_uv_offset = fract(base_uv_offset);

		vec2 adjusted_uv = base_uv * tile_factor;
		adjusted_uv.y *= aspect_ratio;

		vec2 texture_based_offset = texture(texture_offset_uv, base_uv_offset).rg * 2.0 - 1.0;
		vec2 sine_offset = calculate_sine_wave(u_time, sine_time_scale, adjusted_uv, sine_offset_scale);

		vec2 final_waves_uvs = adjusted_uv + texture_based_offset * texture_offset_height + sine_offset * sine_wave_size;
		float water_height = (0.5*sine_offset.y + 0.5*texture_based_offset.y) * 0.5;
		//float water_height = (0.0 + 0.5*texture_based_offset.y) * 0.5;

		vec4 diffuse_color = texture(water_fill_tex, base_uv);
		vec4 shaded_color = mix(diffuse_color, shadow_color, water_height * 1.0);

		vec2 n_uv = fract(adjusted_uv / 5.0);
		vec3 nrm = texture(water_normal_tex, n_uv).rgb;
		nrm = normalize(nrm * 2.0 - 1.0);
		NORMAL = nrm;

		COLOR = vec4(shaded_color.rgb, shaded_color.a * mask_alpha);
	}
}
