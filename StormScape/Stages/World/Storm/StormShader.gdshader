shader_type canvas_item;

uniform vec2 circle_center_pixels;
uniform float radius_pixels;
uniform vec2 viewport_size;
uniform vec2 noise_world_position;

uniform float ring_thickness = 5.0;
uniform float glow_intensity = 1.0;
uniform float noise_scale = 0.1;
uniform float noise_speed = 0.1;
uniform vec4 glow_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform sampler2D gradient_texture;
uniform sampler2D noise_texture;
uniform sampler2D noise_texture2; // Add this line
uniform vec3 noise_color_influence = vec3(1.0, 0.5, 0.8);
uniform float pulse_speed = 1.0;
uniform float pulse_intensity = 0.1;
uniform float color_cycle_speed = 0.5;
uniform vec3 color_cycle_amplitude = vec3(0.5, 0.5, 0.5);
uniform vec3 color_cycle_phase = vec3(0.0, 2.0, 4.0);

void fragment() {
    vec2 screen_pos_pixels = SCREEN_UV * viewport_size;
    float dist = distance(screen_pos_pixels, circle_center_pixels);

    vec2 relative_pos = (screen_pos_pixels - circle_center_pixels) * noise_scale;
    vec2 relative_noise_pos = (screen_pos_pixels - noise_world_position) * noise_scale;
    float time = TIME * noise_speed;

    // Sample first noise texture
    vec2 noise_uv = mod(relative_noise_pos + vec2(time, time), 1.0);
    float n1 = texture(noise_texture, noise_uv).r;

    // Sample second noise texture with a different offset
    vec2 noise_uv2 = mod(relative_noise_pos + vec2(-time, time), 1.0);
    float n2 = texture(noise_texture2, noise_uv2).r;

    // Blend the two noise layers
    float blended_noise = mix(n1, n2, 0.5);

    float gradient_factor = smoothstep(radius_pixels, radius_pixels + 100.0, dist);
    vec4 texture_color = texture(gradient_texture, vec2(gradient_factor, 0.0));

    float pulse = 1.0 + pulse_intensity * sin(TIME * pulse_speed);
    float ring_dist = abs(dist - radius_pixels);
    float glow = smoothstep(ring_thickness, 0.0, ring_dist) * glow_intensity * pulse * step(radius_pixels, dist);
    vec4 ring_color = glow_color * glow * step(radius_pixels, dist) * step(dist, radius_pixels + ring_thickness);

    vec4 noise_color = vec4(blended_noise * noise_color_influence, 1.0) * 0.1;

    vec3 cycle_shift = vec3(
        1.0 + color_cycle_amplitude.r * sin(TIME * color_cycle_speed + color_cycle_phase.r),
        1.0 + color_cycle_amplitude.g * sin(TIME * color_cycle_speed + color_cycle_phase.g),
        1.0 + color_cycle_amplitude.b * sin(TIME * color_cycle_speed + color_cycle_phase.b)
    );
    vec3 shifted_color = texture_color.rgb * cycle_shift;
    vec4 outer_color = vec4(shifted_color, texture_color.a) + noise_color;

    if (dist < radius_pixels) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        COLOR = outer_color + ring_color;
    }
}