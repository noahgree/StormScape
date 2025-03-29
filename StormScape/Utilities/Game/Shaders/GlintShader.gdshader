shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float width : hint_range(0, 10) = 0.0;
uniform int pattern : hint_range(0, 2) = 2;
uniform bool inside = false;
uniform bool add_margins = true;

uniform sampler2D vertical_gradient;
uniform sampler2D color_gradient;
uniform float size_effect: hint_range(-5.0, 5.0, 0.05) = 0.4;
uniform float speed = 0.9;
uniform float highlight_strength: hint_range(-4.0, 4.0, 0.05) = 0.4;
uniform bool color_mode_toggle = true;
uniform float pause_duration = 1.0;
uniform float angle = 35.0;

uniform vec4 tint_color: source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.0;

instance uniform float random_start_offset = 0.0;
instance uniform float final_alpha = 1.0;

void vertex() {
    if (add_margins) {
        VERTEX += (UV * 2.0 - 1.0) * width;
    }
}

bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
    for (float i = -ceil(width); i <= ceil(width); i++) {
        float x = abs(i) > width ? width * sign(i) : i;
        float offset;
        if (pattern == 0) {
            offset = width - abs(x);
        } else if (pattern == 1) {
            offset = floor(sqrt(pow(width + 0.5, 2) - x * x));
        } else if (pattern == 2) {
            offset = width;
        }
        for (float j = -ceil(offset); j <= ceil(offset); j++) {
            float y = abs(j) > offset ? offset * sign(j) : j;
            vec2 xy = uv + texture_pixel_size * vec2(x, y);
            if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(texture, xy).a <= 0.0) == inside) {
                return true;
            }
        }
    }
    return false;
}

void fragment() {
    vec2 uv = UV;
    vec4 base_color = texture(TEXTURE, uv);

    // Margin adjustments
    if (add_margins) {
        vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0));
        uv = (uv - texture_pixel_size * width) * TEXTURE_PIXEL_SIZE / texture_pixel_size;
        if (uv != clamp(uv, vec2(0.0), vec2(1.0))) {
            base_color.a = 0.0;
        } else {
            base_color = texture(TEXTURE, uv);
        }
    }

    // Preserve the sampled color (used for alpha & outline detection)
    vec4 sampled_color = base_color;

    // Compute the tinted (original) pixel color WITHOUT glow
    vec3 tinted_pixel = mix(sampled_color.rgb, tint_color.rgb, tint_color.a);
    // Compute the glowing version for non-outline pixels
    vec3 glowing_pixel = tinted_pixel * glow_intensity;
    vec4 non_outline_color = vec4(glowing_pixel, sampled_color.a);

    // Determine if the outline should be applied
    bool is_outline = (sampled_color.a > 0.0) == inside && hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE);

    vec4 final_color;
    if (is_outline) {
        // For the outline, use the tinted (original) pixel without glow
        final_color = vec4(mix(tinted_pixel, outline_color.rgb, outline_color.a), 1.0);
    } else {
        // For non-outline pixels, use the glowing version
        final_color = non_outline_color;
    }

    // Apply glint effect only on non-outline pixels
    if (!is_outline) {
        float time = TIME * abs(speed);
        float effect_cycle_duration = 1.0 + pause_duration + random_start_offset;
        float mod_time = mod(time, effect_cycle_duration);
        float progress = mod_time / 1.0;
        if (mod_time > 1.0) {
            progress = 1.0;
        }
        if (speed < 0.0) {
            progress = 1.0 - progress;
        }

        float rad_angle = radians(angle);
        vec2 direction = vec2(cos(rad_angle), sin(rad_angle));
        float position_value = dot(UV, direction) / sqrt(2.0);
        float current_time = mix(0.0 - size_effect, 1.0 + size_effect, progress);
        float effect_lower_bound = current_time - size_effect;
        float effect_upper_bound = current_time + size_effect;
        float effect_distance = smoothstep(effect_lower_bound, current_time, position_value) - smoothstep(current_time, effect_upper_bound, position_value);
        float inner_effect_position = smoothstep(effect_lower_bound, effect_upper_bound, position_value);
        vec2 color_position = color_mode_toggle ? vec2(UV.x, inner_effect_position) : vec2(progress);
        vec4 new_color = texture(color_gradient, color_position);
        new_color = mix(non_outline_color, new_color, texture(vertical_gradient, vec2(progress)));
        vec4 effect_color = mix(non_outline_color, new_color, effect_distance * highlight_strength);

        final_color.rgb = mix(final_color.rgb, effect_color.rgb, effect_distance * highlight_strength);
    }
	
	if (final_color.a > 0.0) {
		final_color.a = final_alpha;
	}

    COLOR = final_color;
}