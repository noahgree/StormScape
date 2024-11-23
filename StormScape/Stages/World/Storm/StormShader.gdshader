shader_type canvas_item;

// Existing shader uniforms
uniform vec2 circle_center_pixels;
uniform float radius_pixels;
uniform vec2 viewport_size;
uniform vec2 noise_world_position;

uniform float override_all_alpha = 1.0;

uniform vec2 see_through_center_pixels;
uniform float see_through_radius;
uniform float see_through_opacity = 0.5;

uniform float ring_thickness = 2.3;
uniform float glow_intensity = 4.0;
uniform float noise_scale = 0.003;
uniform float noise_speed = 0.04;
uniform float bottom_noise_speed = 0.2;
uniform float top_noise_speed = 2.75;
uniform float noise_brightness = 1.25;
uniform vec4 glow_color : source_color = vec4(0.722, 0.681, 1, 0.743);
uniform sampler2D noise_texture;
uniform sampler2D noise_texture2;
uniform float pulse_speed = 4.0;
uniform float pulse_intensity = 0.18;
uniform float color_cycle_speed = 0.65;
uniform vec3 color_cycle_amplitude = vec3(0.12, 0.12, 0.12);
uniform vec3 color_cycle_phase = vec3(0.0, 2.0, 4.0);
uniform float reverse_intensity = 0.0;
uniform float gradient_start = 0.0;
uniform float gradient_end = 600.0;
uniform vec4 color1 : source_color = vec4(0.772, 0.384, 0.773, 0.574);
uniform vec4 color2 : source_color = vec4(0.606, 0.322, 1.0, 0.542);
uniform vec4 color3 : source_color = vec4(0.558, 0.396, 1.0, 0.772);
uniform vec4 color4 : source_color = vec4(0.345, 0.001, 0.829, 0.877);
uniform float transition1 = 0.25;
uniform float transition2 = 0.5;
uniform float transition3 = 0.75;
uniform float swirl_intensity = 0.0;
uniform float reflection_thickness = 30.0;
uniform float reflection_intensity = 0.15;
uniform vec4 reflection_color : source_color = vec4(0.287, 0.287, 0.287, 0.293);
uniform float turbulence_intensity = 1.5;

// Rain/snow shader uniforms
uniform int count: hint_range(0, 2000) = 0;
uniform float slant: hint_range(-1.5, 1.5) = 0.15;
uniform float speed: hint_range(5.0, 100.0) = 25.0;
uniform float blur: hint_range(0.0005, 0.1) = 0.003;
uniform vec4 rain_color: source_color = vec4(0.857, 0.903, 1, 0.417);
uniform vec2 size = vec2(0.008, 0.19);

uniform float ripple_intensity = 0.5;
uniform float ripple_frequency = 0.6;
uniform float ripple_speed = 0.5;

float line_sdf(vec2 p, vec2 s) {
    vec2 d = abs(p) - s;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float Hash(float x) {
    return fract(sin(x * 18.34) * 51.78);
}

float Hash2(float x) {
    return fract(sin(x * 25.42) * 21.24);
}

vec2 swirl(vec2 position, vec2 center, float angle) {
    vec2 pos = position - center;
    float s = sin(angle);
    float c = cos(angle);
    vec2 swirled = vec2(
        pos.x * c - pos.y * s,
        pos.x * s + pos.y * c
    );
    return swirled + center;
}

void fragment() {
    vec2 screen_pos_pixels = SCREEN_UV * viewport_size;
    float dist = distance(screen_pos_pixels, circle_center_pixels);

	float see_through_dist = distance(screen_pos_pixels, see_through_center_pixels);
	float see_through_factor = smoothstep(see_through_radius, see_through_radius + 25.0, see_through_dist);

    vec2 relative_pos = (screen_pos_pixels - circle_center_pixels) * noise_scale;
    vec2 relative_noise_pos = (screen_pos_pixels - noise_world_position) * noise_scale;
    float time = TIME * noise_speed;

    float direction_multiplier = mix(1.0, -1.0, reverse_intensity);
    float swirl_angle = direction_multiplier * swirl_intensity * time;

    vec2 swirled_noise_uv = swirl(screen_pos_pixels, circle_center_pixels, swirl_angle);

    vec2 noise_movement_1 = vec2(time * bottom_noise_speed * direction_multiplier, time);
    vec2 noise_movement_2 = vec2(time * top_noise_speed * direction_multiplier, time);

    vec2 turbulence_offset = vec2(
        sin(relative_noise_pos.y * 10.0 + time) * turbulence_intensity,
        cos(relative_noise_pos.x * 10.0 + time) * turbulence_intensity
    );

    vec2 turbulent_noise_uv = swirled_noise_uv + turbulence_offset;

    // Calculate ripple effect
    float ripple_time = TIME * ripple_speed;
    float ripple = sin(dist * ripple_frequency - ripple_time) * ripple_intensity;

    // Apply ripple to the noise UV coordinates
    vec2 ripple_offset = vec2(
        sin(dist * ripple_frequency + ripple_time) * ripple_intensity,
        cos(dist * ripple_frequency + ripple_time) * ripple_intensity
    );

    vec2 rippled_noise_uv = turbulent_noise_uv + ripple_offset;

    // Sample noise textures with the rippled UVs
    float n1_rippled = texture(noise_texture, mod((rippled_noise_uv - noise_world_position) * noise_scale + noise_movement_1, 1.0)).r;
    float n2_rippled = texture(noise_texture2, mod((rippled_noise_uv - noise_world_position) * noise_scale + noise_movement_2, 1.0)).r;

    // Blend the rippled noise
    float blended_rippled_noise = mix(n1_rippled, n2_rippled, 0.5);

    float gradient_factor = smoothstep(radius_pixels + gradient_start, radius_pixels + gradient_end, dist);

    vec4 interpolated_color;
    if (gradient_factor < transition1) {
        interpolated_color = mix(color1, color2, gradient_factor / transition1);
    } else if (gradient_factor < transition2) {
        interpolated_color = mix(color2, color3, (gradient_factor - transition1) / (transition2 - transition1));
    } else {
        interpolated_color = mix(color3, color4, (gradient_factor - transition2) / (transition3 - transition2));
    }

    float pulse = 1.0 + pulse_intensity * cos(TIME * pulse_speed);

	float ring_dist = abs(dist - radius_pixels);
	float glow = smoothstep(ring_thickness, -ring_thickness, ring_dist) * glow_intensity * pulse;
	vec4 ring_color = glow_color * glow;

    vec4 noise_color = vec4(blended_rippled_noise, blended_rippled_noise, blended_rippled_noise, 1.0) * 0.1 * noise_brightness;

    vec3 cycle_shift = vec3(
        1.0 + color_cycle_amplitude.r * sin(TIME * color_cycle_speed + color_cycle_phase.r),
        1.0 + color_cycle_amplitude.g * sin(TIME * color_cycle_speed + color_cycle_phase.g),
        1.0 + color_cycle_amplitude.b * sin(TIME * color_cycle_speed + color_cycle_phase.b)
    );
    vec3 shifted_color = interpolated_color.rgb * cycle_shift;
    vec4 outer_color = vec4(shifted_color, interpolated_color.a) + noise_color;

	vec4 transparent_color = vec4(outer_color.rgb, outer_color.a * (1.0 - see_through_opacity));
	outer_color = mix(transparent_color, outer_color, see_through_factor);

    vec2 reflection_direction = normalize(vec2(n1_rippled - 0.5, n2_rippled - 0.5));
    float reflection_dist = abs(dot(screen_pos_pixels - circle_center_pixels, reflection_direction));
    float reflection_effect = smoothstep(reflection_thickness, 0.0, reflection_dist) * reflection_intensity;
    vec4 reflection_color_effect = reflection_color * reflection_effect;

	// Rain/Snow effect
	vec2 uv = UV;
	vec2 s = size * 0.1;
	float rain_output = 0.0;

	// Calculate the slant angle
	float slant_angle = atan(slant);

	for (int i = 1; i <= count; i++) {
	    float h1 = Hash(float(i));
	    float h2 = Hash2(float(i));

	    // Generate initial positions covering a wider range in X to account for slant
	    float pos_x = h1 * (1.0 + abs(slant) * 2.0) - abs(slant);
	    float pos_y = mod(h2 + TIME * speed * 0.1, 1.0);

	    // Apply slant to the position based on pos_y
	    pos_x += (1.0 - pos_y) * slant;

	    vec2 position = vec2(pos_x, pos_y);

	    // Calculate the relative position and rotate it by -slant_angle
	    vec2 p = uv - position;
	    float s_angle = -slant_angle;
	    float sin_a = sin(s_angle);
	    float cos_a = cos(s_angle);
	    vec2 rotated_p = vec2(
	        cos_a * p.x - sin_a * p.y,
	        sin_a * p.x + cos_a * p.y
	    );

	    // Use the rotated position in line_sdf to create slanted lines
	    float sdf = line_sdf(rotated_p, s);

	    rain_output += clamp(-sdf / blur, 0.0, 1.0);
	}

	vec4 rain_effect = vec4(rain_color.rgb, rain_output);

    if (dist < radius_pixels) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0) + ring_color;
    } else {
        COLOR = outer_color + ring_color + reflection_color_effect;
        COLOR.rgb = mix(COLOR.rgb, rain_effect.rgb, rain_effect.a);
		COLOR.a *= override_all_alpha;
    }
}