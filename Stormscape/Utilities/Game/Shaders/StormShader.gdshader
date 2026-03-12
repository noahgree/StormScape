shader_type canvas_item;
render_mode unshaded;

uniform vec2 circle_center_pixels;
uniform float radius_pixels;
uniform vec2 viewport_size;
uniform vec2 noise_world_position;

uniform float override_all_alpha = 1.0;

uniform vec2 see_through_center_pixels;
uniform float see_through_radius;
uniform float see_through_opacity = 0.5;

uniform float ring_thickness = 2.3;
uniform float ring_glow_intensity = 4.0;

uniform float noise_scale = 0.003;
uniform float noise_speed = 0.04;
uniform float bottom_noise_speed = 0.2;
uniform float top_noise_speed = 2.75;
uniform float noise_brightness = 1.25;

uniform vec4 glow_color : source_color = vec4(0.722, 0.681, 1.0, 0.743);
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

// Rain
uniform int count : hint_range(0, 2000) = 0;
uniform float slant : hint_range(-1.5, 1.5) = 0.15;
uniform float speed : hint_range(5.0, 100.0) = 20.0;
uniform float blur : hint_range(0.0005, 0.1) = 0.002;
uniform vec4 rain_color : source_color = vec4(0.857, 0.903, 1.0, 0.417);
uniform vec2 size = vec2(0.008, 0.19);

uniform float ripple_intensity = 0.5;
uniform float ripple_frequency = 0.6;
uniform float ripple_speed = 0.5;

// Shader-only lightning
uniform float lightning_frequency = 0.0;
uniform float lightning_chance = 0.15;
uniform float lightning_intensity = 1.0;

float line_sdf(vec2 p, vec2 half_size) {
    vec2 d = abs(p) - half_size;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float hash11(float x) {
    return fract(sin(x * 127.1) * 43758.5453123);
}

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 rotate_around(vec2 position, vec2 center, float angle) {
    vec2 p = position - center;
    float s = sin(angle);
    float c = cos(angle);
    return vec2(
        p.x * c - p.y * s,
        p.x * s + p.y * c
    ) + center;
}

float safe_remap(float value, float a, float b) {
    return clamp((value - a) / max(b - a, 0.0001), 0.0, 1.0);
}

vec4 sample_gradient(float t) {
    t = clamp(t, 0.0, 1.0);

    if (t < transition1) {
        return mix(color1, color2, safe_remap(t, 0.0, transition1));
    } else if (t < transition2) {
        return mix(color2, color3, safe_remap(t, transition1, transition2));
    } else if (t < transition3) {
        return mix(color3, color4, safe_remap(t, transition2, transition3));
    } else {
        return color4;
    }
}

float pulse_window(float t, float start, float attack, float hold, float release) {
    float fade_in = smoothstep(start, start + attack, t);
    float fade_out = 1.0 - smoothstep(start + attack + hold, start + attack + hold + release, t);
    return clamp(fade_in * fade_out, 0.0, 1.0);
}

float lightning_amount() {
    if (lightning_frequency <= 0.001 || lightning_intensity <= 0.001 || lightning_chance <= 0.001) {
        return 0.0;
    }

    float t = TIME * lightning_frequency;
    float cell = floor(t);
    float local_t = fract(t);
    float base = cell + 1010.0 * 31.37; // The "1010.0" here is just a random float that acts as the lightning seed

    float active = step(1.0 - lightning_chance, hash11(base + 0.13));

    float start1 = mix(0.06, 0.18, hash11(base + 1.7));
    float attack1 = mix(0.04, 0.08, hash11(base + 2.9));
    float hold1 = mix(0.05, 0.10, hash11(base + 3.8));
    float release1 = mix(0.18, 0.32, hash11(base + 4.6));

    float f1 = active * pulse_window(local_t, start1, attack1, hold1, release1);

    float second_flash = active * step(0.76, hash11(base + 5.3));
    float gap = mix(0.03, 0.08, hash11(base + 6.1));
    float start2 = start1 + attack1 + hold1 + gap;
    float attack2 = attack1 * mix(0.65, 0.90, hash11(base + 7.2));
    float hold2 = hold1 * mix(0.45, 0.70, hash11(base + 8.4));
    float release2 = release1 * mix(0.55, 0.80, hash11(base + 9.1));

    float f2 = second_flash * 0.45 * pulse_window(local_t, start2, attack2, hold2, release2);

    float envelope = clamp(f1 + f2, 0.0, 1.0);

    // Tiny shimmer while active, but no hard strobing.
    float shimmer = 1.0;
    if (envelope > 0.001) {
        shimmer = 0.985 + 0.015 * sin((local_t - start1) * 16.0 + base * 4.1);
    }

    return clamp(envelope * shimmer, 0.0, 1.0) * lightning_intensity;
}

float rain_layer(
    vec2 rain_uv,
    vec2 grid,
    float density,
    float layer_speed,
    float seed,
    float slant_amount,
    vec2 base_size,
    float base_blur
) {
    if (density <= 0.001) {
        return 0.0;
    }

    vec2 flow_uv = rain_uv;
    flow_uv.y -= TIME * speed * 0.02 * layer_speed;
    flow_uv.x += flow_uv.y * slant_amount;

    vec2 cell_uv = flow_uv * grid;
    vec2 cell = floor(cell_uv);
    vec2 local = fract(cell_uv) - 0.5;

    float rnd = hash12(cell + vec2(seed, seed * 1.37));
    float active = step(1.0 - density, rnd);

    float x_jitter = (hash12(cell + vec2(seed * 2.1, seed * 3.7)) - 0.5) * 0.7;
    local.x -= x_jitter;

    // Map original size semantics into cell-local space.
    // Bigger size input now correctly makes bigger streaks.
    float drop_width = clamp(base_size.x * grid.x * 0.10, 0.010, 0.28);
    float drop_length = clamp(base_size.y * grid.y * 0.10 * mix(0.75, 1.25, rnd), 0.08, 1.35);
    float softness = max(base_blur * max(grid.x, grid.y) * 0.10, 0.01);

    vec2 half_size = vec2(drop_width, drop_length);

    float sdf = line_sdf(local, half_size);
    return (1.0 - smoothstep(0.0, softness, sdf)) * active;
}

void fragment() {
    vec2 screen_px = SCREEN_UV * viewport_size;
    float dist_to_center = distance(screen_px, circle_center_pixels);

    float pulse = 1.0 + pulse_intensity * cos(TIME * pulse_speed);
    float ring_dist = abs(dist_to_center - radius_pixels);
    float ring_mask = 1.0 - smoothstep(0.0, max(ring_thickness, 0.0001), ring_dist);
    vec4 ring_color_out = glow_color * (ring_mask * ring_glow_intensity * pulse);

    if (dist_to_center < radius_pixels) {
        COLOR = ring_color_out;
        COLOR.a *= override_all_alpha;
    } else {
        float t = TIME * noise_speed;
        float direction = mix(1.0, -1.0, reverse_intensity);

        vec2 animated_px = screen_px;

        if (abs(swirl_intensity) > 0.001) {
            animated_px = rotate_around(
                animated_px,
                circle_center_pixels,
                direction * swirl_intensity * t
            );
        }

        if (turbulence_intensity > 0.001) {
            vec2 base_noise_pos = (screen_px - noise_world_position) * noise_scale;
            animated_px += vec2(
                sin(base_noise_pos.y * 10.0 + t) * turbulence_intensity,
                cos(base_noise_pos.x * 10.0 + t) * turbulence_intensity
            );
        }

        if (ripple_intensity > 0.001) {
            float ripple_t = TIME * ripple_speed;
            animated_px += vec2(
                sin(dist_to_center * ripple_frequency + ripple_t),
                cos(dist_to_center * ripple_frequency + ripple_t)
            ) * ripple_intensity;
        }

        vec2 noise_uv_1 = fract(
            (animated_px - noise_world_position) * noise_scale +
            vec2(t * bottom_noise_speed * direction, t)
        );
        vec2 noise_uv_2 = fract(
            (animated_px - noise_world_position) * noise_scale +
            vec2(t * top_noise_speed * direction, t)
        );

        float n1 = texture(noise_texture, noise_uv_1).r;
        float n2 = texture(noise_texture2, noise_uv_2).r;
        float blended_noise = mix(n1, n2, 0.5);

        float gradient_t = safe_remap(
            dist_to_center,
            radius_pixels + gradient_start,
            radius_pixels + gradient_end
        );
        gradient_t = gradient_t * gradient_t * (3.0 - 2.0 * gradient_t);

        vec4 base_color = sample_gradient(gradient_t);

        vec3 cycle_shift = vec3(
            1.0 + color_cycle_amplitude.r * sin(TIME * color_cycle_speed + color_cycle_phase.r),
            1.0 + color_cycle_amplitude.g * sin(TIME * color_cycle_speed + color_cycle_phase.g),
            1.0 + color_cycle_amplitude.b * sin(TIME * color_cycle_speed + color_cycle_phase.b)
        );

        vec4 noise_color = vec4(vec3(blended_noise * 0.1 * noise_brightness), 0.0);
        vec4 outer_color = vec4(base_color.rgb * cycle_shift, base_color.a) + noise_color;

        float see_through_dist = distance(screen_px, see_through_center_pixels);
        float see_through_mask = smoothstep(
            see_through_radius,
            see_through_radius + 25.0,
            see_through_dist
        );

        vec4 transparent_outer = vec4(
            outer_color.rgb,
            outer_color.a * (1.0 - see_through_opacity)
        );
        outer_color = mix(transparent_outer, outer_color, see_through_mask);

        vec4 reflection_fx = vec4(0.0);
        if (reflection_intensity > 0.001 && reflection_thickness > 0.001) {
            vec2 reflection_dir = normalize(vec2(n1 - 0.5, n2 - 0.5) + vec2(0.0001));
            float reflection_dist = abs(dot(screen_px - circle_center_pixels, reflection_dir));
            float reflection_mask = 1.0 - smoothstep(0.0, reflection_thickness, reflection_dist);
            reflection_fx = reflection_color * (reflection_mask * reflection_intensity);
        }

        // Lightning now just brightens the storm slightly.
        float lightning = lightning_amount();
        if (lightning > 0.001) {
            float brighten_outer = 1.0 + lightning * (0.16 + 0.10 * blended_noise);
            float brighten_ring = 1.0 + lightning * 0.12;
            float brighten_reflection = 1.0 + lightning * 0.08;

            outer_color.rgb *= brighten_outer;
            ring_color_out.rgb *= brighten_ring;
            reflection_fx.rgb *= brighten_reflection;
        }

        vec4 final_color = outer_color + ring_color_out + reflection_fx;

        // Rain:
        // X is world-anchored so horizontal camera motion doesn't drag it.
        // Y is screen-space so moving up/down doesn't change fall speed.
        if (count > 0 && rain_color.a > 0.001) {
            float density = sqrt(clamp(float(count) / 2000.0, 0.0, 1.0));

            vec2 rain_uv = (screen_px - noise_world_position) / max(viewport_size, vec2(1.0));

            float rain_a = rain_layer(
                rain_uv,
                vec2(140.0, 36.0),
                density,
                1.0,
                11.0,
                slant,
                size,
                blur
            );

            rain_a += rain_layer(
                rain_uv + vec2(0.173, 0.0),
                vec2(90.0, 24.0),
                density * 0.75,
                1.35,
                29.0,
                slant * 1.15,
                size * vec2(1.10, 0.92),
                blur * 1.10
            );

            rain_a = clamp(rain_a * rain_color.a, 0.0, 1.0);
            final_color.rgb = mix(final_color.rgb, rain_color.rgb, rain_a);
        }

        final_color.a *= override_all_alpha;
        COLOR = final_color;
    }
}